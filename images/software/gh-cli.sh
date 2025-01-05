#!/usr/bin/env bash

# This script installs the GitHub CLI

if grep -q "Ubuntu\|Debian" "/etc/os-release"; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get install dirmngr -y
  apt-get update
  apt-get install gh -y --no-install-recommends
  apt-get clean
  rm -rf /var/lib/apt/lists/*
elif grep -q "CentOS\|Red Hat" "/etc/redhat-release"; then
  yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  yum install -y gh
  yum clean all
fi
