FROM ubuntu:20.04

LABEL \ 
    org.opencontainers.image.source https://github.com/some-natalie/kubernoodles \
    org.opencontainers.image.title ubuntu-focal-runner \
    org.opencontainers.image.description "An Ubuntu Focal (20.04 LTS) based runner image for GitHub Actions" \
    org.opencontainers.image.authors "Natalie Somersall (@some-natalie)" \
    org.opencontainers.image.licenses=MIT \
    org.opencontainers.image.documentation https://github.com/some-natalie/kubernoodles/README.md

# Set environment variables needed at build
ENV DEBIAN_FRONTEND=noninteractive

# Copy in environment variables not needed at build
COPY .env /.env

# Install base software
RUN apt-get update \
    && apt-get install -y software-properties-common \
    && apt-get dist-upgrade -y \
    && apt-get install -y \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    gcc \
    git \
    iptables \
    libyaml-dev \
    locales \
    lsb-release \
    pkg-config \
    sudo \
    supervisor \
    time \
    tzdata \
    unzip \
    wget \
    zip \
    && apt-get autoclean \
    && apt-get autoremove

# Runner user
RUN adduser --disabled-password --gecos "" --uid 1000 runner \
    && groupadd docker \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers

# Install GitHub CLI
COPY software/gh-cli.sh gh-cli.sh
RUN bash gh-cli.sh && rm gh-cli.sh

# Install kubectl
COPY software/kubectl.sh kubectl.sh
RUN bash kubectl.sh && rm kubectl.sh

# Set up additional repos
COPY software/repos-deb.sh repos.sh
RUN bash repos.sh && rm repos.sh

# Install Azure CLI
RUN apt-get update \
    && apt-get install -y powershell \
    && apt-get autoclean \
    && apt-get autoremove
COPY software/azure-deb.sh azure.sh
RUN bash azure.sh && rm azure.sh
COPY software/powershell-modules.ps1 powershell-modules.ps1
RUN pwsh powershell-modules.ps1 && rm powershell-modules.ps1

# Runner agent and Docker configs
ARG TARGETPLATFORM=linux/amd64
ARG RUNNER_VERSION=2.288.1
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.12
ARG DEBUG=false

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Docker installation
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x86_64 ; fi \
  && if ! curl -L -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz"; then \
    echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${ARCH}'"; \
    exit 1; \
  fi; \
    echo "Downloaded Docker from https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz"; \
  tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/ \
  ; \
  rm docker.tgz; \
  dockerd --version; \
  docker --version

ENV RUNNER_ASSETS_DIR=/runnertmp

# Runner download supports amd64 as x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && apt-get autoclean \
    && apt-get autoremove

RUN echo AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache > /runner.env \
  && mkdir /opt/hostedtoolcache \
  && chgrp runner /opt/hostedtoolcache \
  && chmod g+rwx /opt/hostedtoolcache

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh
COPY entrypoint.sh /usr/local/bin/
COPY docker/daemon.json /etc/docker/daemon.json

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/entrypoint.sh /usr/local/bin/modprobe

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && curl -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

VOLUME /var/lib/docker

# No group definition, as that makes it harder to run docker.
USER runner

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["startup.sh"]
