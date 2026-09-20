# syntax=docker/dockerfile:1.7

ARG NODEJS_IMAGE=node:24-alpine3.24

# -----------------------------------------------------------------------------
# PLANET / Root node: modern ZeroTier, open build only.
# -----------------------------------------------------------------------------
FROM alpine:3.24 AS planet_builder
ARG PLANET_ZEROTIER_VERSION=1.16.2
ARG PLANET_ZEROTIER_SOURCE_REF=1.16.2
RUN apk add --no-cache \
    bash build-base ca-certificates curl git linux-headers openssl-dev pkgconf
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
# Controller experiment: test current ZeroTier release with the standalone controller API.
# -----------------------------------------------------------------------------
FROM alpine:3.24 AS controller_builder
ARG CONTROLLER_ZEROTIER_VERSION=1.16.2
ARG CONTROLLER_ZEROTIER_SOURCE_REF=fc5c3ec22090b5b2a0f274e863651fe9ca489bf4
RUN apk add --no-cache \
    bash build-base ca-certificates curl git linux-headers openssl-dev pkgconf
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH=/root/.cargo/bin:${PATH}
WORKDIR /src/ZeroTierOne
RUN git init . \
    && git remote add origin https://github.com/zerotier/ZeroTierOne.git \
    && git fetch --depth 1 origin "${CONTROLLER_ZEROTIER_SOURCE_REF}" \
    && git checkout --detach FETCH_HEAD \
    && git rev-parse HEAD > /tmp/controller-zerotier-commit
RUN make -j"$(nproc)" ZT_NONFREE=1 \
    && strip --strip-unneeded zerotier-one

# -----------------------------------------------------------------------------
# ztmkworld helper source.
# This is a build-time dependency only; ZTNet is not a runtime component.
# -----------------------------------------------------------------------------
FROM alpine:3.24 AS mkworld_source
ARG MKWORLD_SOURCE_REF=3ba175a682d03edd72516d830667ee08fe3cf262
RUN apk add --no-cache git ca-certificates \
    && mkdir -p /src \
    && git -C /src init \
    && git -C /src remote add origin https://github.com/sinamics/ztnet.git \
    && git -C /src fetch --depth 1 origin "${MKWORLD_SOURCE_REF}" \
    && git -C /src checkout --detach FETCH_HEAD \
    && git -C /src rev-parse HEAD > /src/.source-commit

# -----------------------------------------------------------------------------
# ztncui: project-maintained controller UI, built from vendored source.
# -----------------------------------------------------------------------------
ARG NODEJS_IMAGE
FROM ${NODEJS_IMAGE} AS ztncui_builder
WORKDIR /app
COPY ui/ztncui/src/package.json ./
RUN npm install --omit=dev --no-audit --no-fund \
    && npm cache clean --force \
    && rm -rf /root/.npm
COPY ui/ztncui/src ./
RUN test -f app.js \
    && test -f bin/www \
    && node --check app.js \
    && node --check bin/www

FROM ${NODEJS_IMAGE} AS mkworld_builder
ARG TARGETPLATFORM
WORKDIR /app
COPY --from=mkworld_source /src/ztnodeid/build/linux_amd64/ztmkworld ztmkworld_amd64
COPY --from=mkworld_source /src/ztnodeid/build/linux_arm64/ztmkworld ztmkworld_arm64
RUN case "${TARGETPLATFORM}" in \
      "linux/amd64") cp ztmkworld_amd64 /usr/local/bin/ztmkworld ;; \
      "linux/arm64") cp ztmkworld_arm64 /usr/local/bin/ztmkworld ;; \
      *) echo "Unsupported architecture: ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/ztmkworld

# -----------------------------------------------------------------------------
# One business image: PLANET + Controller + project-maintained ztncui.
# -----------------------------------------------------------------------------
ARG NODEJS_IMAGE
FROM ${NODEJS_IMAGE} AS runtime
ARG SOVEREIGN_VERSION=0.4.0
ARG PLANET_ZEROTIER_VERSION=1.16.2
ARG CONTROLLER_ZEROTIER_VERSION=1.14.2

ENV NODE_ENV=production \
    PORT=3000 \
    PLANET_ZT_PORT=9994 \
    CONTROLLER_ZT_PORT=9993 \
    PLANET_FILE_SERVER_PORT=3001 \
    PLANET_HOME=/data/planet/one \
    WORLD_DIR=/data/planet/world \
    DIST_DIR=/data/planet/dist \
    CONFIG_DIR=/data/planet/config \
    CONTROLLER_HOME=/data/controller/one

RUN apk add --no-cache \
    bash ca-certificates coreutils curl libgcc libstdc++ openssl tini

# Project-maintained ztncui is the sole management UI.
COPY --from=ztncui_builder /app /opt/ztncui
COPY ui/ztncui/LICENSE /opt/ztncui/LICENSE
COPY ui/ztncui/UPSTREAM.md /opt/ztncui/UPSTREAM.md
COPY --from=mkworld_builder /usr/local/bin/ztmkworld /usr/local/bin/ztmkworld

# Keep the two ZeroTier installations physically separate inside the same image.
RUN mkdir -p /opt/zerotier-planet /opt/zerotier-controller /usr/local/share/zerotier-sovereign
COPY THIRD_PARTY_NOTICES.md /usr/local/share/zerotier-sovereign/THIRD_PARTY_NOTICES.md
COPY --from=planet_builder /src/ZeroTierOne/zerotier-one /opt/zerotier-planet/zerotier-one
COPY --from=planet_builder /tmp/planet-zerotier-commit /usr/local/share/zerotier-sovereign/planet-zerotier-commit
COPY --from=controller_builder /src/ZeroTierOne/zerotier-one /opt/zerotier-controller/zerotier-one
COPY --from=controller_builder /tmp/controller-zerotier-commit /usr/local/share/zerotier-sovereign/controller-zerotier-commit
COPY --from=controller_builder /src/ZeroTierOne/nonfree/LICENSE.md /usr/local/share/zerotier-sovereign/ZEROTIER-NONFREE-LICENSE.md
COPY --from=mkworld_source /src/.source-commit /usr/local/share/zerotier-sovereign/mkworld-source-commit
RUN ln -s zerotier-one /opt/zerotier-planet/zerotier-idtool \
    && ln -s zerotier-one /opt/zerotier-planet/zerotier-cli \
    && ln -s zerotier-one /opt/zerotier-controller/zerotier-idtool \
    && ln -s zerotier-one /opt/zerotier-controller/zerotier-cli \
    && printf '%s\n' "${SOVEREIGN_VERSION}" > /usr/local/share/zerotier-sovereign/version \
    && printf '%s\n' "${PLANET_ZEROTIER_VERSION}" > /usr/local/share/zerotier-sovereign/planet-zerotier-version \
    && printf '%s\n' "${CONTROLLER_ZEROTIER_VERSION}" > /usr/local/share/zerotier-sovereign/controller-zerotier-version

COPY rootfs/ /
RUN chmod +x /usr/local/bin/* \
    && mkdir -p /data/planet/one /data/planet/world /data/planet/dist /data/planet/config /data/controller/one \
    && mkdir -p /var/lib \
    && rm -rf /var/lib/zerotier-one \
    && ln -s /data/controller/one /var/lib/zerotier-one

LABEL org.opencontainers.image.title="ZeroTier Sovereign" \
      org.opencontainers.image.description="Self-owned ZeroTier PLANET + standalone Controller + maintained ztncui UI" \
      org.opencontainers.image.version="${SOVEREIGN_VERSION}"

EXPOSE 9994/tcp 9994/udp 9993/udp 3000/tcp 3001/tcp
HEALTHCHECK --interval=30s --timeout=8s --start-period=120s --retries=5 \
  CMD ["/usr/local/bin/sovereign-healthcheck"]
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/sovereign-entrypoint"]
