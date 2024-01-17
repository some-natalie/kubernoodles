FROM --platform=linux/amd64 summerwind/actions-runner:latest
ENV VERSION_ID="22.04"
ENV DEBIAN_FRONTEND=noninteractive

RUN sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list" 

RUN sudo wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/Release.key -O- | sudo apt-key add -

RUN sudo apt-get update -y \
  && sudo apt-get upgrade -y \
  && sudo apt-get install uidmap vim -y \
  && sudo rm -rf /var/lib/apt/lists/*
  
USER root

# Adding private CA
# COPY ca.crt /usr/local/share/ca-certificates/ca.crt
# RUN update-ca-certificates

RUN usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers

RUN chgrp -R 0 /run /usr/local /var/cache /var/log /var/run \
    && chmod -R g=u /run /usr/local /var/cache /var/log /var/run 

USER runner
