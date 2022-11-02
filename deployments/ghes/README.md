# GHES runners

There's nothing special about these runners.  They deploy to a different Kubernetes cluster (the `docker-desktop` environment or the `open-shift` environment) and attach to a different organization in GHES for testing/demonstration.  The [`bootstrap.sh`](bootstrap.sh) script takes a URL and token to set up test environments very quickly.

## Local environments

This bootstrap script has been tested and is used routinely on [Docker Desktop's local Kubernetes cluster](https://docs.docker.com/desktop/kubernetes/), [Azure Kubernetes Service](https://azure.microsoft.com/en-us/products/kubernetes-service/#overview), and [RedHat OpenShift Local](https://access.redhat.com/documentation/en-us/red_hat_openshift_local).

For OpenShift, because these are privileged pods, you must allow this explicitly in the namespaces the pods will run in.

    ```shell
    oc adm policy add-scc-to-user privileged -z default -n runners
    oc adm policy add-scc-to-user privileged -z default -n test-runners
    ```
