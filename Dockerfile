# syntax=docker/dockerfile:1.7

ARG NODEJS_IMAGE=node:24-bookworm-slim

# -----------------------------------------------------------------------------
# PLANET / Root node: modern ZeroTier, open build only.
# -----------------------------------------------------------------------------
FROM debian:bookworm AS planet_builder
ARG PLANET_ZEROTIER_VERSION=1.16.2
ARG PLANET_ZEROTIER_SOURCE_REF=1.16.2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl git pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH=/root/.cargo/bin:${PATH}
WORKDIR /src/ZeroTierOne
RUN git init . \
    && git remote add origin https://github.com/zerotier/ZeroTierOne.git \
    && git fetch --depth 1 origin "${PLANET_ZEROTIER_SOURCE_REF}" \
    && git checkout --detach FETCH_HEAD \
    && git rev-parse HEAD > /tmp/planet-zerotier-commit
# Do not enable ZT_NONFREE / ZT_CONTROLLER here.
RUN make -j"$(nproc)" \
    && strip --strip-unneeded zerotier-one

# -----------------------------------------------------------------------------
# Controller: compatibility branch that still contains the standalone controller.
# Build on bookworm so the binary uses runtime-compatible glibc/OpenSSL.
# -----------------------------------------------------------------------------
FROM debian:bookworm AS controller_builder
ARG CONTROLLER_ZEROTIER_VERSION=1.14.2
ARG CONTROLLER_ZEROTIER_SOURCE_REF=1.14.2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl git pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH=/root/.cargo/bin:${PATH}
WORKDIR /src/ZeroTierOne
RUN git init . \
    && git remote add origin https://github.com/zerotier/ZeroTierOne.git \
    && git fetch --depth 1 origin "${CONTROLLER_ZEROTIER_SOURCE_REF}" \
    && git checkout --detach FETCH_HEAD \
    && git rev-parse HEAD > /tmp/controller-zerotier-commit
RUN make -j"$(nproc)" \
    && strip --strip-unneeded zerotier-one

# -----------------------------------------------------------------------------
# ZTNet source. ZTNET_SOURCE_REF may be a release tag OR an immutable commit SHA.
# -----------------------------------------------------------------------------
FROM alpine:3.22 AS ztnet_source
ARG ZTNET_SOURCE_REF=v0.8.3
RUN apk add --no-cache git ca-certificates \
    && mkdir -p /src \
    && git -C /src init \
    && git -C /src remote add origin https://github.com/sinamics/ztnet.git \
    && git -C /src fetch --depth 1 origin "${ZTNET_SOURCE_REF}" \
    && git -C /src checkout --detach FETCH_HEAD \
    && git -C /src rev-parse HEAD > /src/.source-commit \
    && printf '%s\n' "${ZTNET_SOURCE_REF}" > /src/.source-ref

ARG NODEJS_IMAGE
FROM --platform=$BUILDPLATFORM ${NODEJS_IMAGE} AS ztnet_base

FROM ztnet_base AS ztnet_deps
WORKDIR /app
COPY --from=ztnet_source /src/package.json /src/package-lock.json ./
COPY --from=ztnet_source /src/prisma ./prisma
# Use the release's lock file. Do not pin Prisma independently from upstream.
RUN npm ci && npx prisma generate

FROM ztnet_base AS ztnet_builder
ARG NEXT_PUBLIC_APP_VERSION
WORKDIR /app
COPY --from=ztnet_deps /app/node_modules ./node_modules
COPY --from=ztnet_source /src ./
RUN SKIP_ENV_VALIDATION=1 npm run build

FROM ztnet_base AS ztmkworld_builder
ARG TARGETPLATFORM
WORKDIR /app
COPY --from=ztnet_source /src/ztnodeid/build/linux_amd64/ztmkworld ztmkworld_amd64
COPY --from=ztnet_source /src/ztnodeid/build/linux_arm64/ztmkworld ztmkworld_arm64
RUN case "${TARGETPLATFORM}" in \
      "linux/amd64") cp ztmkworld_amd64 /usr/local/bin/ztmkworld ;; \
      "linux/arm64") cp ztmkworld_arm64 /usr/local/bin/ztmkworld ;; \
      *) echo "Unsupported architecture: ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/ztmkworld

# -----------------------------------------------------------------------------
# One business image: PLANET + Controller + ZTNet.
# PostgreSQL deliberately stays in its own container.
# -----------------------------------------------------------------------------
ARG NODEJS_IMAGE
FROM ${NODEJS_IMAGE} AS runtime
ARG SOVEREIGN_VERSION=0.3.0
ARG PLANET_ZEROTIER_VERSION=1.16.2
ARG CONTROLLER_ZEROTIER_VERSION=1.14.2
ARG ZTNET_VERSION=v0.8.3
ARG NEXT_PUBLIC_APP_VERSION=v0.8.3

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_APP_VERSION=${NEXT_PUBLIC_APP_VERSION} \
    PORT=3000 \
    PLANET_ZT_PORT=9994 \
    CONTROLLER_ZT_PORT=9993 \
    PLANET_FILE_SERVER_PORT=3001 \
    PLANET_HOME=/data/planet/one \
    WORLD_DIR=/data/planet/world \
    DIST_DIR=/data/planet/dist \
    CONFIG_DIR=/data/planet/config \
    CONTROLLER_HOME=/data/controller/one \
    PATH=/app/node_modules/.bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl python3 supervisor tini \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl --fail -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo \"$VERSION_CODENAME\")-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client-17 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ZTNet runtime. Resolve its runtime tool versions from the upstream lock file,
# but install them in the TARGET platform image. This avoids copying BUILDPLATFORM
# native modules into arm64 releases while also avoiding independent hard-coded pins.
WORKDIR /app
COPY --from=ztnet_source /src/package-lock.json /tmp/ztnet-package-lock.json
RUN set -eux; \
    prisma_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/prisma']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    prisma_client_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/@prisma/client']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    cuid2_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/@paralleldrive/cuid2']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    tsnode_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/ts-node']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    tsx_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/tsx']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    dotenv_version="$(node -e "const p=require('/tmp/ztnet-package-lock.json'); const v=p.packages?.['node_modules/dotenv']?.version; if(!v) process.exit(2); process.stdout.write(v)")"; \
    npm install --no-audit --no-fund --no-save "prisma@${prisma_version}" "@prisma/client@${prisma_client_version}" "@paralleldrive/cuid2@${cuid2_version}" "dotenv@${dotenv_version}" "ts-node@${tsnode_version}" "tsx@${tsx_version}"; \
    npm cache clean --force; \
    rm -rf /root/.npm; \
    rm -f /tmp/ztnet-package-lock.json package.json package-lock.json

COPY --from=ztnet_builder /app/next.config.mjs ./
COPY --from=ztnet_builder /app/public ./public
COPY --from=ztnet_builder /app/package.json ./package.json
COPY --from=ztnet_builder --chown=1001:1001 /app/.next/standalone ./
COPY --from=ztnet_builder --chown=1001:1001 /app/.next/static ./.next/static
COPY --from=ztnet_builder --chown=1001:1001 /app/prisma ./prisma
COPY --from=ztnet_builder --chown=1001:1001 /app/init-db.sh ./init-db.sh
COPY --from=ztmkworld_builder /usr/local/bin/ztmkworld /usr/local/bin/ztmkworld
RUN sed -i 's#npx prisma#/app/node_modules/.bin/prisma#g' /app/init-db.sh \
    && chmod +x /app/init-db.sh \
    && touch /app/.env \
    && /app/node_modules/.bin/prisma generate

# Keep the two ZeroTier installations physically separate inside the same image.
RUN mkdir -p /opt/zerotier-planet /opt/zerotier-controller /usr/local/share/zerotier-sovereign
COPY --from=planet_builder /src/ZeroTierOne/zerotier-one /opt/zerotier-planet/zerotier-one
COPY --from=planet_builder /tmp/planet-zerotier-commit /usr/local/share/zerotier-sovereign/planet-zerotier-commit
COPY --from=controller_builder /src/ZeroTierOne/zerotier-one /opt/zerotier-controller/zerotier-one
COPY --from=controller_builder /tmp/controller-zerotier-commit /usr/local/share/zerotier-sovereign/controller-zerotier-commit
COPY --from=ztnet_source /src/.source-commit /usr/local/share/zerotier-sovereign/ztnet-commit
COPY --from=ztnet_source /src/.source-ref /usr/local/share/zerotier-sovereign/ztnet-ref
RUN ln -s zerotier-one /opt/zerotier-planet/zerotier-idtool \
    && ln -s zerotier-one /opt/zerotier-planet/zerotier-cli \
    && ln -s zerotier-one /opt/zerotier-controller/zerotier-idtool \
    && ln -s zerotier-one /opt/zerotier-controller/zerotier-cli \
    && printf '%s\n' "${SOVEREIGN_VERSION}" > /usr/local/share/zerotier-sovereign/version \
    && printf '%s\n' "${PLANET_ZEROTIER_VERSION}" > /usr/local/share/zerotier-sovereign/planet-zerotier-version \
    && printf '%s\n' "${CONTROLLER_ZEROTIER_VERSION}" > /usr/local/share/zerotier-sovereign/controller-zerotier-version \
    && printf '%s\n' "${ZTNET_VERSION}" > /usr/local/share/zerotier-sovereign/ztnet-version

COPY rootfs/ /
RUN chmod +x /usr/local/bin/* \
    && mkdir -p /data/planet/one /data/planet/world /data/planet/dist /data/planet/config /data/controller/one \
    && mkdir -p /var/lib \
    && rm -rf /var/lib/zerotier-one \
    && ln -s /data/controller/one /var/lib/zerotier-one

LABEL org.opencontainers.image.title="ZeroTier Sovereign" \
      org.opencontainers.image.description="Self-owned ZeroTier PLANET + standalone Controller + ZTNet UI" \
      org.opencontainers.image.version="${SOVEREIGN_VERSION}"

EXPOSE 9994/tcp 9994/udp 9993/udp 3000/tcp 3001/tcp
HEALTHCHECK --interval=30s --timeout=8s --start-period=120s --retries=5 \
  CMD ["/usr/local/bin/sovereign-healthcheck"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/sovereign-entrypoint"]
