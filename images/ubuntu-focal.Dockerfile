FROM ubuntu:20.04

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.298.2

# Docker and Docker Compose arguments
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.19
ARG COMPOSE_VERSION=v2.11.2

# Dumb-init version
ARG DUMB_INIT_VERSION=1.2.5

# Other arguments
ARG DEBUG=false

# Label all the things!!
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
COPY images/.env /.env

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install base software
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  apt-transport-https \
  apt-utils \
  ca-certificates \
  cifs-utils \
  curl \
  gcc \
  git \
  iptables \
  jq \
  libyaml-dev \
  locales \
  lsb-release \
  pkg-config \
  software-properties-common \
  sudo \
  supervisor \
  time \
  tzdata \
  unzip \
  wget \
  zip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Runner user
RUN adduser --disabled-password --gecos "" --uid 1000 runner \
  && groupadd docker \
  && usermod -aG sudo runner \
  && usermod -aG docker runner \
  && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers

# Install GitHub CLI
COPY images/software/gh-cli.sh /gh-cli.sh
RUN bash /gh-cli.sh && rm /gh-cli.sh

# Install kubectl
COPY images/software/kubectl.sh /kubectl.sh
RUN bash /kubectl.sh && rm /kubectl.sh

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Docker installation
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && export ARCH \
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

# Docker-compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose ; \
  chmod +x /usr/local/bin/docker-compose ; \
  docker-compose --version

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
  && apt-get autoremove

# Create the hosted tool cache directory
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
  && chgrp runner /opt/hostedtoolcache \
  && chmod g+rwx /opt/hostedtoolcache
RUN mkdir /opt/statictoolcache \
  && chgrp runner /opt/statictoolcache \
  && chmod g+rwx /opt/statictoolcache

# Install dumb-init, arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && export ARCH \
  && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
  && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
  && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
  && chmod +x /usr/local/bin/dumb-init

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY images/startup.sh images/logger.sh images/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/startup.sh /usr/bin/entrypoint.sh

COPY images/supervisor/ /etc/supervisor/conf.d/
COPY images/docker/daemon.json /etc/docker/daemon.json

VOLUME /var/lib/docker

# No group definition, as that makes it harder to run docker.
USER runner

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["startup.sh"]
