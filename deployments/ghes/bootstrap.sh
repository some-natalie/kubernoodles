#!/bin/bash

# This script is designed to use docker-desktop's cluster to GHES/GHAE real fast :)

# Inputs
# $1: The GHES server to use (e.g. "https://github.yourcompany.com")
# $2: The GHES token to use (e.g. "ghp_123456789")

# Remove the trailing slash from the server URL if it exists
if [[ "$1" == *"/" ]]; then
    URL="${1::-1}"
else
    URL="$1"
fi

# Setup cert-manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.9.1 --set installCRDs=true

# Setup ARC
kubectl create namespace actions-runner-system
helm install -n actions-runner-system actions-runner-controller actions-runner-controller/actions-runner-controller --version=0.20.2
kubectl set env deploy actions-runner-controller -c manager GITHUB_ENTERPRISE_URL="$URL" --namespace actions-runner-system
kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token="$2"
kubectl create namespace runners
kubectl create namespace test-runners

# Don't deploy runners automatically, edit them to test whatever is needed
