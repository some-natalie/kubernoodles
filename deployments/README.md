# Deployments

This folder contains all the deployment files for the Kubernetes cluster.  A deployment is a discrete group of runners that can have unique hardware, scaling functions, or scope (repository, organization, or enterprise wide.  These are defined by [actions-runner-controller](https://github.com/actions/actions-runner-controller) and there's more information in the linked documentation.

## Runner profiles

Each `helm-<runner>.yml` file is the single source of truth for that runner's
pod template, image, and scaling settings. Production deployments use the
profile directly (see [manual-deploy.yml](../.github/workflows/manual-deploy.yml)).
The image test workflows use the same profile with Helm `--set-string`
overrides for the `:test` image tag. UBI tests also set
`template.spec.containers[0].imagePullPolicy=Always`; the Wolfi test sets
`containerMode.kubernetesModeWorkVolumeClaim.storageClassName=standard` for
Minikube instead of the production `k8s-mode` storage class.

For example, the Jammy test workflow passes both
`template.spec.initContainers[0].image` and
`template.spec.containers[0].image` with the `:test` tag; the Docker-in-Docker
sidecar remains unchanged. When editing a runner, change its profile, not a
separate test copy. Helm applies command-line overrides on top of `-f`, and
the corresponding image test workflow runs when its profile changes.

Fork pull requests cannot publish to the upstream container registry or access
the GitHub App secret for runner registration. Their image workflows instead
build a temporary image, load it into Minikube, render this profile with the
temporary image, and run a non-privileged smoke pod. Upstream-authorized runs
continue to deploy ARC and run the full tests on registered runners.

More details as noted:

- The Docker image in use here is public, but in order to avoid rate-limiting in public registries, the `imagePullSecrets` is still set to a secret in the `runners` namespace.  You will have to set this for private registries.
- Docker-in-Docker presents some unique networking challenges, outlined in more detail in the [nested virtualization tips](../docs/tips-and-tricks.md#nested-virtualization).  MTU is one of the more common challenges.
- Docker-in-Docker relies on `--privileged` execution to mount `procfs` and `sysfs`.  Running the rootless container provides an additional layer of security by disallowing privileged execution within the pod and running the nested Docker instance in rootless mode, but the runner container is still privileged.
- The `volumes` and `volumeMounts` blocks give each pod read-only access to a hosted tool cache.  This allows users to call pre-made Actions, like [`actions/setup-python`](https://github.com/actions/setup-python), without needing to download and install Python at every job run if the version of what the user wants is already in cache.  Read the [tool cache setup guide](../cluster-configs/README.md#tool-cache-for-runners-using-persistentvolumeclaim) for more.
- Resource requests and limits are how Kubernetes controls the compute resources any pod in a cluster gets.  There's more about this from the [official documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) and a [Google guide to resource requests and limits](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits).
- Labels are used by your users in GitHub to specify what type of compute to dispatch the job to.  One runner can have many labels.  In this case, this runner is labeled with "docker", "ubuntu", and "focal".  There's a lot more to read about this in the [official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners).
- `dependabot` is a special label that allows Dependabot to use this runner to generate pull requests.  Read [GitHub's Dependabot runner documentation](https://docs.github.com/en/enterprise-server@latest/admin/github-actions/enabling-github-actions-for-github-enterprise-server/managing-self-hosted-runners-for-dependabot-updates) for more; this label should be applied to Linux-based runners that can run Docker containers.  Because `dependabot` runners will pull a giant Docker container (4+ GB) on each run, that label is not included in the deployments here.
- When you're using GitHub.com, try to not use `ubuntu-latest` or any of the other labels used by GitHub's hosted runners ([list](https://docs.github.com/en/enterprise-cloud@latest/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners)) so that you can either ensure that the job does or does not go to the self-hosted runners.  When using GitHub AE or GitHub Enterprise Server, feel free to use these labels as there's no conflict.
