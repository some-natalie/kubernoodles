FROM ubuntu:22.04 AS build

# GitHub runner arguments
ARG RUNNER_VERSION=2.322.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.6.2

# Docker and Compose arguments
ARG DOCKER_VERSION=28.0.1
ARG COMPOSE_VERSION=v2.34.0

# Dumb-init version
ARG DUMB_INIT_VERSION=1.2.5

# Other arguments, expose TARGETPLATFORM for multi-arch builds
ARG DEBUG=false
ARG TARGETPLATFORM

# Label all the things!!
LABEL org.opencontainers.image.source = "https://github.com/vivacitylabs/kubernoodles"
LABEL org.opencontainers.image.path "images/rootless-ubuntu-jammy.Dockerfile"
LABEL org.opencontainers.image.title "rootless-ubuntu-jammy"
LABEL org.opencontainers.image.description "An Ubuntu Jammy (22.04 LTS) based runner image for GitHub Actions, rootless"
# LABEL org.opencontainers.image.authors "Natalie Somersall (@some-natalie)"
LABEL org.opencontainers.image.licenses "MIT"
LABEL org.opencontainers.image.documentation https://github.com/some-natalie/kubernoodles/README.md

# Set environment variables needed at build or run
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

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
  gnupg \
  iproute2 \
  iptables \
  jq \
  libyaml-dev \
  locales \
  lsb-release \
  openssh-client \
  openssl \
  pigz \
  pkg-config \
  software-properties-common \
  ssh \
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

# Make and set the working directory
RUN mkdir -p /home/runner \
  && chown -R $USERNAME:$GID /home/runner

WORKDIR /home/runner


# # Set up nodejs 16
COPY images/software/node16.sh /node16.sh
RUN bash /node16.sh && rm /node16.sh

# # Set up nodejs 18
COPY images/software/node18.sh /node18.sh
RUN bash /node18.sh && rm /node18.sh

# # Set up nodejs 20
COPY images/software/node20.sh /node20.sh
RUN bash /node20.sh && rm /node20.sh

# # Set up yarn
COPY images/software/yarn.sh /yarn.sh
RUN bash /yarn.sh && rm /yarn.sh


# # Set up nodejs 16
COPY images/software/node16.sh /node16.sh
RUN bash /node16.sh && rm /node16.sh

# # Set up nodejs 18
COPY images/software/node18.sh /node18.sh
RUN bash /node18.sh && rm /node18.sh

# # Set up nodejs 20
COPY images/software/node20.sh /node20.sh
RUN bash /node20.sh && rm /node20.sh

# # Set up yarn
COPY images/software/yarn.sh /yarn.sh
RUN bash /yarn.sh && rm /yarn.sh

# Install GitHub CLI
COPY images/software/gh-cli.sh /gh-cli.sh
RUN bash /gh-cli.sh && rm /gh-cli.sh

# Install kubectl
COPY images/software/kubectl.sh /kubectl.sh
RUN bash /kubectl.sh && rm /kubectl.sh

# Install helm
COPY images/software/get-helm.sh /helm.sh
RUN bash /helm.sh && rm /helm.sh

# Install Docker
RUN export DOCKER_ARCH=x86_64 \
  && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
  && curl -fLo docker.tgz https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
  && tar zxvf docker.tgz \
  && rm -rf docker.tgz

RUN install -o root -g root -m 755 docker/* /usr/bin/ && rm -rf docker

# Runner download supports amd64 as x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && echo "ARCH: $ARCH" \
  && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
  && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
  && tar xzf ./runner.tar.gz \
  && rm runner.tar.gz \
  && ./bin/installdependencies.sh \
  && apt-get autoclean \
  && rm -rf /var/lib/apt/lists/*

# Install container hooks
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
  && unzip ./runner-container-hooks.zip -d ./k8s \
  && rm runner-container-hooks.zip

# Install dumb-init, arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && export ARCH \
  && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
  && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
  && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
  && chmod +x /usr/local/bin/dumb-init

# Make the rootless runner directory and externals directory executable
RUN mkdir -p /run/user/1000 \
  && chown runner:runner /run/user/1000 \
  && chmod a+x /run/user/1000 \
  && mkdir -p /home/runner/externals \
  && chown runner:runner /home/runner/externals \
  && chmod a+x /home/runner/externals

# Docker-compose installation
RUN ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
  && export ARCH \
  && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
  && if [ "$ARCH" = "amd64" ]; then export ARCH=x86_64 ; fi \
  && curl --create-dirs -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-${ARCH}" -o /home/runner/bin/docker-compose ; \
  chmod +x /home/runner/bin/docker-compose

# squash it!
FROM scratch AS final

# Label all the things!!
LABEL org.opencontainers.image.source="https://github.com/some-natalie/kubernoodles"
LABEL org.opencontainers.image.path="images/rootless-ubuntu-jammy.Dockerfile"
LABEL org.opencontainers.image.title="rootless-ubuntu-jammy"
LABEL org.opencontainers.image.description="An Ubuntu Jammy (22.04 LTS) based runner image for GitHub Actions, rootless"
LABEL org.opencontainers.image.authors="Natalie Somersall (@some-natalie)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.documentation="https://github.com/some-natalie/kubernoodles/README.md"

# Set environment variables needed at build or run
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

# Add the Python "User Script Directory" to the PATH
ENV HOME=/home/runner
ENV PATH="${PATH}:${HOME}/.local/bin:/home/runner/bin"
ENV ImageOS=ubuntu22

# No group definition, as that makes it harder to run docker.
USER runner

COPY --from=build / /

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
