/*
 * Derived from ZeroTier One attic/world/mkworld.cpp.
 * Original copyright ZeroTier, Inc.
 * License: GPL-3.0-or-later (matching the original utility header).
 *
 * Changes in this project:
 *   - roots are loaded from moon.json
 *   - world timestamp is supplied at runtime instead of being hard-coded to 2019
 *   - validation/error handling is explicit
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <chrono>
#include <exception>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>
#include <node/Constants.hpp>
#include <node/World.hpp>
#include <node/C25519.hpp>
#include <node/Identity.hpp>
#include <node/InetAddress.hpp>
#include <osdep/OSUtils.hpp>

using namespace ZeroTier;
using json = nlohmann::json;

static uint64_t now_ms()
{
    return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

static void usage(const char *argv0)
{
    fprintf(stderr, "Usage: %s [--timestamp <milliseconds>]\n", argv0);
}

int main(int argc, char **argv)
{
    uint64_t ts = now_ms();
    for (int i = 1; i < argc; ++i) {
        const std::string arg(argv[i]);
        if (arg == "--timestamp") {
            if (++i >= argc) {
                usage(argv[0]);
                return 64;
            }
            try {
                ts = std::stoull(argv[i]);
            } catch (...) {
                fprintf(stderr, "FATAL: invalid timestamp\n");
                return 64;
            }
        } else if (arg == "-h" || arg == "--help") {
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            return 64;
        }
    }

    try {
        std::string previous, current;
        if ((!OSUtils::readFile("previous.c25519", previous)) || (!OSUtils::readFile("current.c25519", current))) {
            C25519::Pair np(C25519::generate());
            previous.assign((const char *)np.pub.data, ZT_C25519_PUBLIC_KEY_LEN);
            previous.append((const char *)np.priv.data, ZT_C25519_PRIVATE_KEY_LEN);
            current = previous;
            if (!OSUtils::writeFile("previous.c25519", previous) || !OSUtils::writeFile("current.c25519", current)) {
                fprintf(stderr, "FATAL: could not persist world signing keys\n");
                return 1;
            }
            fprintf(stderr, "INFO: created persistent initial world signing keys\n");
        }

        const size_t kp_len = ZT_C25519_PUBLIC_KEY_LEN + ZT_C25519_PRIVATE_KEY_LEN;
        if (previous.length() != kp_len || current.length() != kp_len) {
            fprintf(stderr, "FATAL: previous.c25519/current.c25519 are invalid\n");
            return 1;
        }

        C25519::Pair previousKP;
        memcpy(previousKP.pub.data, previous.data(), ZT_C25519_PUBLIC_KEY_LEN);
        memcpy(previousKP.priv.data, previous.data() + ZT_C25519_PUBLIC_KEY_LEN, ZT_C25519_PRIVATE_KEY_LEN);
        C25519::Pair currentKP;
        memcpy(currentKP.pub.data, current.data(), ZT_C25519_PUBLIC_KEY_LEN);
        memcpy(currentKP.priv.data, current.data() + ZT_C25519_PUBLIC_KEY_LEN, ZT_C25519_PRIVATE_KEY_LEN);

        std::string fileContent;
        if (!OSUtils::readFile("moon.json", fileContent)) {
            fprintf(stderr, "FATAL: failed to read moon.json\n");
            return 1;
        }

        const json config = json::parse(fileContent);
        if (!config.contains("roots") || !config["roots"].is_array() || config["roots"].empty()) {
            fprintf(stderr, "FATAL: moon.json has no roots\n");
            return 1;
        }

        std::vector<World::Root> roots;
        for (const auto &root : config["roots"]) {
            if (!root.contains("identity") || !root.contains("stableEndpoints")) {
                fprintf(stderr, "FATAL: root lacks identity/stableEndpoints\n");
                return 1;
            }
            roots.emplace_back();
            roots.back().identity = Identity(root["identity"].get<std::string>().c_str());
            for (const auto &endpoint : root["stableEndpoints"]) {
                roots.back().stableEndpoints.emplace_back(endpoint.get<std::string>().c_str());
            }
            if (roots.back().stableEndpoints.empty()) {
                fprintf(stderr, "FATAL: root has no stable endpoints\n");
                return 1;
            }
        }

        const uint64_t id = ZT_WORLD_ID_EARTH;
        fprintf(stderr, "INFO: signing planet id=%llu timestamp=%llu roots=%zu\n",
            (unsigned long long)id, (unsigned long long)ts, roots.size());

        World nw = World::make(World::TYPE_PLANET, id, ts, currentKP.pub, roots, previousKP);
        Buffer<ZT_WORLD_MAX_SERIALIZED_LENGTH> out;
        nw.serialize(out, false);

        World test;
        test.deserialize(out, 0);
        if (test != nw) {
            fprintf(stderr, "FATAL: world serialization self-test failed\n");
            return 1;
        }

        if (!OSUtils::writeFile("world.bin", std::string((const char *)out.data(), out.size()))) {
            fprintf(stderr, "FATAL: failed to write world.bin\n");
            return 1;
        }
        fprintf(stderr, "INFO: wrote world.bin (%u bytes)\n", out.size());
        return 0;
    } catch (const std::exception &e) {
        fprintf(stderr, "FATAL: %s\n", e.what());
        return 1;
    } catch (...) {
        fprintf(stderr, "FATAL: unknown error\n");
        return 1;
    }
}
