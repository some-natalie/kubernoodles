FROM quay.io/podman/stable:v4

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.295.0

# Other arguments
ARG DEBUG=false

# Label all the things!!
LABEL \ 
    org.opencontainers.image.source https://github.com/some-natalie/kubernoodles \
    org.opencontainers.image.title podman-runner \
    org.opencontainers.image.description "A Podman (Fedora) based runner image for GitHub Actions" \
    org.opencontainers.image.authors "Natalie Somersall (@some-natalie)" \
    org.opencontainers.image.licenses=MIT \
    org.opencontainers.image.documentation https://github.com/some-natalie/kubernoodles/README.md

# Copy in environment variables not needed at build
COPY images/.env /.env

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV RUNNER_ASSETS_DIR=/runnertmp

# Dependencies setup
RUN dnf install -y \
    buildah \
    jq \
    podman-docker \
    podman-compose \
    skopeo \
    slirp4netns \
    && rm /etc/dnf/protected.d/sudo.conf \
    && dnf remove sudo -y \
    && dnf clean all \
    && touch /etc/containers/nodocker

# Install kubectl
COPY images/software/kubectl.sh /kubectl.sh
RUN bash /kubectl.sh && rm /kubectl.sh

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
    && dnf clean all

# Copy files into the image
COPY images/logger.sh /usr/bin/logger.sh
COPY images/entrypoint.sh /usr/local/bin/
COPY --chown=podman:podman images/podman/87-podman.conflist /home/podman/.config/cni/net.d/87-podman.conflist
COPY images/podman/11-tcp-mtu-probing.conf /etc/sysctl.d/11-tcp-mtu-probing.conf
COPY images/podman/registries.conf /etc/containers/registries.conf
COPY images/podman/storage.conf /etc/containers/storage.conf

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && sed -i 's|\[machine\]|\#\[machine\]|g' /usr/share/containers/containers.conf \
    && mkdir -p /github/home \
    && mkdir /github/workflow \
    && mkdir /github/file_commands \
    && mkdir /github/workspace \
    && chown -R podman:podman /github

VOLUME $HOME/.local/share/containers/storage

USER podman

ENTRYPOINT ["entrypoint.sh"]
