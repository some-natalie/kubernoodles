FROM quay.io/podman/stable:v4

# Target architecture
ARG TARGETPLATFORM=linux/amd64

# GitHub runner arguments
ARG RUNNER_VERSION=2.301.1

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

# The UID env var should be used in child Containerfile.
ENV UID=1000
ENV GID=0
ENV USERNAME="podman"
ENV RUNNER_ASSETS_DIR=/runnertmp

# Dependencies setup
RUN dnf install -y \
    buildah \
    fuse-overlayfs \
    jq \
    podman-docker \
    podman-compose \
    skopeo \
    shadow-utils \
    slirp4netns \
    xz \
    --exclude container-selinux \
    && dnf -y reinstall shadow-utils \
    && rm /etc/dnf/protected.d/sudo.conf \
    && dnf remove sudo -y \
    && dnf clean all \
    && touch /etc/containers/nodocker

# This is to mimic the OpenShift behaviour of adding the dynamic user to group 0.
RUN usermod -G 0 $USERNAME
ENV HOME /home/${USERNAME}
WORKDIR /home/${USERNAME}

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

# Create the hosted tool cache directory
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chown podman:podman /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache
RUN mkdir /opt/statictoolcache \
    && chown podman:podman /opt/statictoolcache \
    && chmod g+rwx /opt/statictoolcache

# Copy files into the image
COPY images/logger.sh /usr/bin/logger.sh
COPY images/entrypoint.sh /usr/local/bin/
COPY images/podman-startup.sh /usr/local/bin/
COPY images/podman/11-tcp-mtu-probing.conf /etc/sysctl.d/11-tcp-mtu-probing.conf
COPY images/podman/containers.conf /home/podman/.config/containers/containers.conf
COPY images/podman/registries.conf /etc/containers/registries.conf

RUN chgrp -R 0 /etc/containers/ \
    && chmod -R a+r /etc/containers/ \
    && chmod -R g+w /etc/containers/

# Use VFS since fuse does not work
# https://github.com/containers/buildah/blob/master/vendor/github.com/containers/storage/storage.conf
RUN mkdir -vp /home/${USERNAME}/.config/containers && \
    printf '[storage]\ndriver = "vfs"\n' > /home/${USERNAME}/.config/containers/storage.conf && \
    chown -Rv ${USERNAME} /home/${USERNAME}/.config/

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/podman-startup.sh \
    && sed -i 's|\[machine\]|\#\[machine\]|g' /usr/share/containers/containers.conf \
    && mkdir -p /github/home \
    && mkdir /github/workflow \
    && mkdir /github/file_commands \
    && mkdir /github/workspace \
    && chown -R podman:podman /github

USER $UID

CMD [ "podman-startup.sh"]