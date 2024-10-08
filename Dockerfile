# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS builder

ARG WIREGUARD_VERSION

COPY scripts/start-wireguard.sh /scripts/
COPY patches /patches

# hadolint ignore=SC2046
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install util-linux \
    && homelab install build-essential git \
    # Download wireguard-tools repo. \
    && homelab download-git-repo \
        https://git.zx2c4.com/wireguard-tools \
        ${WIREGUARD_VERSION:?} \
        /root/wireguard-tools \
    # Build the wireguard tools. \
    && make -C /root/wireguard-tools/src -j$(nproc) \
    # Copy the built binaries/scripts. \
    && mkdir -p /wg-build \
    && cp /root/wireguard-tools/src/wg /wg-build \
    && cp /root/wireguard-tools/src/wg-quick/linux.bash /wg-build/wg-quick

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG PACKAGES_TO_INSTALL

# hadolint ignore=DL4006,SC2035
RUN \
    --mount=type=bind,target=/scripts,from=builder,source=/scripts \
    --mount=type=bind,target=/patches,from=builder,source=/patches \
    --mount=type=bind,target=/wg-build,from=builder,source=/wg-build \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Install dependencies. \
    && homelab install util-linux patch ${PACKAGES_TO_INSTALL:?} \
    # Install wireguard. \
    && cp /wg-build/* /usr/bin/ \
    # Patch wireguard. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -n 1 patch -p1 -i) \
    # Set up the wireguard start up script. \
    && mkdir -p /opt/wireguard \
    && cp /scripts/start-wireguard.sh /opt/wireguard \
    && ln -sf /opt/wireguard/start-wireguard.sh /opt/bin/start-wireguard \
    # Clean up. \
    && homelab remove util-linux patch \
    && homelab cleanup

CMD ["start-wireguard"]
STOPSIGNAL SIGTERM
