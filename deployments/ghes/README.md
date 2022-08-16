# GHES runners

There's nothing special about these runners.  They deploy to a different Kubernetes cluster (the `bare-metal` environment) and attach to a different organization in GHES.  The [`bootstrap.sh`](bootstrap.sh) script takes a URL and token to set up test environments very quickly.
