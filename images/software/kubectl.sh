#!/usr/bin/env bash

# This script installs the latest version of kubectl

# Download
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Validate
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check | grep -q "kubectl: OK"

# Install
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
