# Deployments

This folder contains all the deployment files for the Kubernetes cluster.  A deployment is a discrete group of runners that can have unique hardware, scaling functions, or scope (repository, organization, or enterprise wide.  These are defined by [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller#usage) and there's more information in the linked documentation.

## Example deployment

Here's an example deployment file with comments:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment  # manage these as a "set" of runners, not individually
metadata:
  name: ubuntu-focal  # give it a name for humans to read
  namespace: runners  # specify the Kubernetes namespace these live in
spec:
  replicas: 2  # I want 2 of these, please :)
  template:
    spec:
      organization: universal-exports-ltd  # attached to this organization
      group: secret-agent-test  # GitHub can group runners by name for management, so these are in "secret-agent-test"
      env: []  # envirnoment stuff for Kubernetes can be passed here - read `actions-runner-controller` docs before using this, otherwise leave it empty!
      ephemeral: true  # throw out the pod and redeploy it fresh after each run
      image: ghcr.io/some-natalie/kubernoodles/ubuntu-focal:latest  # where is the Docker image to use as a pod
      imagePullPolicy: IfNotPresent  # pull this image only if it isn't already on the Kubernetes node
      imagePullSecrets:
        - name: ghcr  # credentials needed to log in to the image registry, more on this below
      dockerdWithinRunnerContainer: true  # can this support Docker-in-Docker, implies `privileged: true`, more on this below
      dockerMTU: 1450  # set the MTU size of the Docker agent in the container, more on this below
      volumeMounts:  # this uses the read only cache set up in ../cluster-configs/runner-tool-cache.yml, more on this below
        - mountPath: /opt/hostedtoolcache  # mount path from within the container
          name: runnertoolcache
          readOnly: true
      volumes:
        - name: runnertoolcache
          persistentVolumeClaim:
            claimName: test-tool-cache-pvc  # which persistent volume claim to use
      resources:
        limits:  # the max size any individual runner can get to
          cpu: "4000m"
          memory: "8Gi"
        requests:  # the guaranteed amount of compute any individual runner gets
          cpu: "200m"
          memory: "200Mi"
      labels:  # custom labels for GitHub Actions to target, more on this below
      - dependabot # special label to allow Dependabot to use this for compute, more on this below
      - docker
      - ubuntu
      - focal
```

More details as noted:

- The Docker image in use here is public, but in order to avoid rate-limiting in public registries, the `imagePullSecrets` is still set to a secret in the `runners` namespace.  You will have to set this for private registries.
- Docker-in-Docker presents some unique networking challenges, outlined in more detail [here](../docs/tips-and-tricks.md#nested-virtualization).  MTU is one of the more common challenges.
- Docker-in-Docker relies on `--privileged` execution to mount `procfs` and `sysfs`.  Running the rootless container provides an additional layer of security by disallowing privileged execution within the pod and running the nested Docker instance in rootless mode, but the runner container is still privileged.
- The `volumes` and `volumeMounts` blocks give each pod read-only access to a hosted tool cache.  This allows users to call pre-made Actions, like [`actions/setup-python`](https://github.com/actions/setup-python), without needing to download and install Python at every job run if the version of what the user wants is already in cache.  More about this [here](../cluster-configs/README.md#tool-cache-for-runners-using-persistentvolumeclaim).
- Resource requests and limits are how Kubernetes controls the compute resources any pod in a cluster gets.  There's more about this from the [official documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) and a helpful Google blog post [here](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits) if you'd like to learn more.
- Labels are used by your users in GitHub to specify what type of compute to dispatch the job to.  One runner can have many labels.  In this case, this runner is labeled with "docker", "ubuntu", and "focal".  There's a lot more to read about this in the [official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners).
- `dependabot` is a special label that allows Dependabot to use this runner to generate pull requests.  More about this feature is [here](https://docs.github.com/en/enterprise-server@latest/admin/github-actions/enabling-github-actions-for-github-enterprise-server/managing-self-hosted-runners-for-dependabot-updates) - note that this label should be applied to Linux-based runners that can run Docker containers.
- When you're using GitHub.com, try to not use `ubuntu-latest` or any of the other labels used by GitHub's hosted runners ([list](https://docs.github.com/en/enterprise-cloud@latest/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners)) so that you can either ensure that the job does or does not go to the self-hosted runners.  When using GitHub AE or GitHub Enterprise Server, feel free to use these labels as there's no conflict.
