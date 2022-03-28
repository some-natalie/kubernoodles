FROM quay.io/podman/stable:v3.4.4

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.289.1

# Other arguments
ARG DEBUG=false

# Label all the things!!
LABEL \ 
    org.opencontainers.image.source https://github.com/some-natalie/kubernoodles \
    org.opencontainers.image.title podman-runner \
    org.opencontainers.image.description "A Podman (Fedora 35) based runner image for GitHub Actions" \
    org.opencontainers.image.authors "Natalie Somersall (@some-natalie)" \
    org.opencontainers.image.licenses=MIT \
    org.opencontainers.image.documentation https://github.com/some-natalie/kubernoodles/README.md

# Copy in environment variables not needed at build
COPY images/.env /.env

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV RUNNER_ASSETS_DIR=/runnertmp

# Runner download supports amd64 as x64
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && export ARCH \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && dnf install buildah skopeo podman-docker podman-compose -y \
    && dnf clean all

# Copy files into the image
COPY images/logger.sh /opt/bash-utils/logger.sh
COPY images/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh 

VOLUME /var/lib/docker

# No group definition, as that makes it harder to run docker.
USER runner

ENTRYPOINT ["entrypoint.sh"]
