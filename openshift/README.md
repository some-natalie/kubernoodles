## GitHub Actions Runner Controller (Community Version) for OpenShift 4.X

Source : https://github.com/actions-runner-controller/actions-runner-controller

There are multiple ways of installing ARC, I have chosen to use GitHub Apps to store credentials and access controls and to configure my runners at the *Org* level so that all repos underneath could have access to them. I also will install everything using .yaml files vs Helm.

### Cert-Manager Installation
Prior to installing ARC, you will need to install and configure cert-manager, this can be done by installing the `cert-manager` operator from the Operator Hub. Once the operator is installed (using the defaults), we will need to setup the private CA cert & key.

1. Copy your ca.crt & ca.key files locally

2. Create a SECRET with these files in the openshift-operators namespace \
  `oc create secret tls ca-key-pair --cert=ca.crt --key=ca.key`

3. I chose to provide acces to the cluster by creating a kind ClusterIssuer
    ```
      kind: ClusterIssuer
      apiVersion: cert-manager.io/v1
      metadata:
        name: my-clusterissuer
      spec:
        selfSigned:
          ca:
            secretName: ca-key-pair
      ```

### ARC Installation w/ GitHub Apps Authentication
Releases : https://github.com/actions/actions-runner-controller/releases/

1. Install the current release \
`oc create -f https://github.com/actions/actions-runner-controller/releases/download/v0.27.6/actions-runner-controller.yaml`

3. When deploying the solution for a GHES environment you need to provide an additional environment variable as part of the controller deployment \
  `oc set env deploy controller-manager -c manager GITHUB_ENTERPRISE_URL=https://${YOUR_GHES_SERVER} -n actions-runner-system`

4. To support docker containers use _privileged_ & anyuid access \
  `oc adm policy add-scc-to-user privileged -z default -n actions-runner-system`
  `oc adm policy add-scc-to-user anyuid -z default -n actions-runner-system`

### GitHub App Authentication
You can create a GitHub App for either your user account or any organization, below are the app permissions required for each supported type of runner.

**Required Permissions for Repository Runners:**
* Actions (read)
* Administration (read / write)
* Checks (read) (if you are going to use Webhook Driven Scaling)
* Metadata (read)

**Required Permissions for Organization Runners:**
* Actions (read)
* Metadata (read)

**Organization Permissions**
* Self-hosted runners (read / write)

### GitHub App for your organization
1. Replace the `${PARTS}` of the following URL with your GHES address & organization name before opening it. Then enter any unique name in the "GitHub App name" field, and hit the "Create GitHub App" button at the bottom of the page to create a GitHub App.

    `https://${YOUR_GHES_SERVER}/organizations/${YOUR_ORG}/settings/apps/new?url=http://github.com/actions/actions-runner-controller&webhook_active=false&public=false&administration=write&organization_self_hosted_runners=write&actions=read&checks=read`

    You will see an App ID on the page of the GitHub App you created as follows, the value of this App ID will be used later.

2. Download the private key file by pushing the "Generate a private key" button at the bottom of the GitHub App page. This file will also be used later.

3. Go to the "Install App" tab on the left side of the page and install the GitHub App that you created for your account or organization. \
    ##### ```NOTE: You will need to Installation ID, to retrieve it go to your ORG that you've installed the app into, visit Settings > GitHub Apps > {YOUR_APP} > and then when you highlight the URL in your browser. The number at the end would be your Intallation ID, example: https://${YOUR_GHES_SERVER}/organizations/${YOUR_ORG}/settings/installation/${INSTALLATION_ID}.```

4. Register the App ID `${APP_ID}`, Installation ID `${INSTALLATION_ID}`, and the downloaded private key file `${PRIVATE_KEY_FILE_PATH}` to OpenShift as a secret.
  ```
  $ kubectl create secret generic controller-manager \
      -n actions-runner-system \
      --from-literal=github_app_id=${APP_ID} \
      --from-literal=github_app_installation_id=${INSTALLATION_ID} \
      --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH}
  ```

### Runner Deployments
There are additional ways to launch your runners, here I chose using kind: RunnerDeployment
#### NOTE: Keep in mind that OpenShift will not natively display your deployments, to view them as well as the later HorizontalRunnerAutoscaler, you'll need to use `oc get runnerdeployment`, `oc get runner', `oc get hra` or `oc get horizonalrunnerautoscaler`.

   ```
   apiVersion: actions.summerwind.dev/v1alpha1
    kind: RunnerDeployment
    metadata:
      name: example-runner-deployment
    spec:
      template:
        spec:
          organization: ${ORG_NAME}
          #repository: example/myrepo

    ---
    apiVersion: actions.summerwind.dev/v1alpha1
    kind: HorizontalRunnerAutoscaler
    metadata:
      name: example-runner-deployment-autoscaler
    spec:
      scaleTargetRef:
        name: example-runner-deployment
      minReplicas: 1
      maxReplicas: 5
      metrics:
      - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
        repositoryNames:
        - example/my-repo
        - example/myother-repo

```
There are a lot of options here, so I am only showing the defaults, but if you'd like an example I have included my scripts under [manifests](./manifests/. Additionally, I have evaluated two custom runners - one based on docker and the other based on podman (buildah). I will include these as examples under [builds](./builds).
