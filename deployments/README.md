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
      dockerdWithinRunnerContainer: true  # can this support Docker-in-Docker
      dockerMTU: 1450  # set the MTU size of the Docker agent in the container, more on this below
      resources:
        limits:  # the max size any individual runner can get to
          cpu: "4000m"
          memory: "8Gi"
        requests:  # the guaranteed amount of compute any individual runner gets
          cpu: "200m"
          memory: "200Mi"
      labels:  # custom labels for GitHub Actions to target, more on this below
      - docker
      - ubuntu
      - focal
      - ubuntu-latest
```

More details as noted:

- The Docker image in use here is public, but in order to avoid rate-limiting in public registries, the `imagePullSecrets` is still set to a secret in the `runners` namespace.  You will have to set this for private registries.
- Docker-in-Docker presents some unique networking challenges, outlined in more detail [here](../docs/tips-and-tricks.md#nested-virtualization).
- Resource requests and limits are how Kubernetes controls the compute resources any pod in a cluster gets.  There's more about this from the [official documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) and a helpful Google blog post [here](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits) if you'd like to learn more.
- Labels are used by your users in GitHub to specify what type of compute to dispatch the job to.  One runner can have many labels.  In this case, this runner is labeled with "docker", "ubuntu", "focal", and "ubuntu-latest".  There's a lot more to read about this in the [official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners).
