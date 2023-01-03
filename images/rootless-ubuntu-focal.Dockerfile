FROM ubuntu:20.04

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.300.2

# Docker and Docker Compose arguments
ENV CHANNEL=stable
ARG COMPOSE_VERSION=v2.14.2

# Dumb-init version
ARG DUMB_INIT_VERSION=1.2.5

# Other arguments
ARG DEBUG=false

# Label all the things!!
LABEL \ 
    org.opencontainers.image.source https://github.com/some-natalie/kubernoodles \
    org.opencontainers.image.title rootless-ubuntu-focal-runner \
    org.opencontainers.image.description "An Ubuntu Focal (20.04 LTS) based runner image for GitHub Actions, rootless" \
    org.opencontainers.image.authors "Natalie Somersall (@some-natalie)" \
    org.opencontainers.image.licenses=MIT \
    org.opencontainers.image.documentation https://github.com/some-natalie/kubernoodles/README.md

# Set environment variables needed at build
ENV DEBIAN_FRONTEND=noninteractive

# Copy in environment variables not needed at build
COPY images/.env /.env

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install base software
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    gcc \
    git \
    iproute2 \
    iptables \
    jq \
    libyaml-dev \
    locales \
    lsb-release \
    openssl \
    pigz \
    pkg-config \
    software-properties-common \
    time \
    tzdata \
    uidmap \
    unzip \
    wget \
    xz-utils \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Runner user
RUN adduser --disabled-password --gecos "" --uid 1000 runner

# Install GitHub CLI
COPY images/software/gh-cli.sh /gh-cli.sh
RUN bash /gh-cli.sh && rm /gh-cli.sh

# Install kubectl
COPY images/software/kubectl.sh /kubectl.sh
RUN bash /kubectl.sh && rm /kubectl.sh

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Setup subuid and subgid so that "--userns-remap=default" works
RUN set -eux; \
    addgroup --system dockremap; \
    adduser --system --ingroup dockremap dockremap; \
    echo 'dockremap:165536:65536' >> /etc/subuid; \
    echo 'dockremap:165536:65536' >> /etc/subgid

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
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

# Create the hosted tool cache directory
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp runner /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache
RUN mkdir /opt/statictoolcache \
    && chgrp runner /opt/statictoolcache \
    && chmod g+rwx /opt/statictoolcache

# Configure hooks folder structure
COPY images/hooks /etc/arc/hooks/

# Install dumb-init, arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && export ARCH \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY images/rootless-startup.sh images/logger.sh images/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/rootless-startup.sh /usr/bin/entrypoint.sh

# Make the rootless runner directory executable
RUN mkdir /run/user/1000 \
    && chown runner:runner /run/user/1000 \
    && chmod a+x /run/user/1000

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin:/home/runner/bin"
ENV ImageOS=ubuntu20
ENV DOCKER_HOST=unix:///run/user/1000/docker.sock
ENV XDG_RUNTIME_DIR=/run/user/1000

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment \
    && echo "DOCKER_HOST=${DOCKER_HOST}" >> /etc/environment \
    && echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" >> /etc/environment \
    && echo "kernel.unprivileged_userns_clone=1" >> /etc/sysctl.conf

ENV HOME=/home/runner

# No group definition, as that makes it harder to run docker.
USER runner

# Docker installation
ENV SKIP_IPTABLES=1
RUN curl -fsSL https://get.docker.com/rootless | sh
COPY --chown=runner:runner images/docker/daemon.json /home/runner/.config/docker/daemon.json

# Docker-compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /home/runner/bin/docker-compose ; \
    chmod +x /home/runner/bin/docker-compose

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["rootless-startup.sh"]
