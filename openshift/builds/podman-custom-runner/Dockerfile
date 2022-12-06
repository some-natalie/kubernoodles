FROM quay.io/podman/stable:v4.3.1

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.299.1

# Other arguments
ARG DEBUG=false

ENV RUNNER_ASSETS_DIR=/runnertmp
ENV STORAGE_OPTS="overlay.mount_program=/usr/bin/fuse-overlayfs"

# Dependencies setup
RUN dnf install -y \
    buildah \
    podman-docker \
    podman-compose \
    skopeo \
    slirp4netns \
    fuse \
    curl \
    && dnf clean all

# Removing kubectl - runner load via GitHub Actions instead
# RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
#     && mv kubectl /usr/local/bin/

# Runner download supports amd64 as x64
RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && export ARCH \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && touch /etc/containers/nodocker \
    && dnf clean all

COPY logger.sh /opt/bash-utils/logger.sh
COPY entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && sed -i 's|\[machine\]|\#\[machine\]|g' /usr/share/containers/containers.conf \
    && sed -i 's|\#ignore_chown_errors = "false"|ignore_chown_errors = "true"|g' /etc/containers/storage.conf

VOLUME $HOME/.local/share/containers/storage
USER podman

ENTRYPOINT ["entrypoint.sh"]
