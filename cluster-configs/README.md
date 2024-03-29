# Kubernetes roles

This folder contains additional YAML files to apply if you'd like, and what they do.

- [Service accounts](#service-accounts) needed for GitHub Actions to deploy its' own runners
- [Creating a tool cache](#tool-cache-for-runners-using-persistentvolumeclaim) to reduce bandwidth usage on setting up tools on each and every job run, such as [`actions/setup-python`](https://github.com/actions/setup-python).

---

## Service accounts

These accounts exist in the Kubernetes cluster for GitHub Actions to use to deploy itself.  You'll take the `kubeconfig` file for each account, then encode it for storage in GitHub Secrets.  There are two, one for each namespace we created for the runners.

- `test-deploy-user.yml`
- `prod-deploy-user.yml`

You use these by copying them to the server and running the commands below as the user account you created to manage Kubernetes.

```shell
kubectl apply -f test-deploy-user.yml
kubectl apply -f prod-deploy-user.yml
```

### Storing the service account configs in GitHub Secrets

Because you don't want to ever use structured data as a secret ([source](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-secrets)), we need to do a little magic to make kubeconfig file usable by GitHub.  Once you have made the service accounts, here's what needs to happen.

First, we need to get the kubeconfig file for the service account.  You can get this directly out of a program like [Lens](https://k8slens.dev/), but let's do this the hard way.

:information_source:  Hope it goes without saying, but these are fake secrets for a demo, shamelessly pilfered from [the guide](http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/) I used for part of this.  Don't go sharing the real values from your cluster around thoughtlessly.

1. First, find the name of the token generated by creating the account.  In this case, it's `test-user-token-2vpgp`.

    ```shell
    $ kubectl describe sa test-user -n test-runners

    Name:                test-user
    Namespace:           test-runners
    Labels:              <none>
    Annotations:         <none>
    Image pull secrets:  <none>
    Mountable secrets:   ghes-actions-deploy (not found)
                         test-user-token-2vpgp
    Tokens:              test-user-token-2vpgp
    Events:              <none>
    ```

1. Next, let's fetch that token.

    ```shell
    $ kubectl describe secrets test-user-token-2vpgp -n test-runners

    Name:         test-user-token-2vpgp
    Namespace:    test-runners
    Labels:       <none>
    Annotations:  kubernetes.io/service-account.name: test-user
                  kubernetes.io/service-account.uid: a7413efa-b40e-4a24-ba7d-21d8c38bd07a

    Type:  kubernetes.io/service-account-token

    Data
    ====
    namespace:  12 bytes
    token:      eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InNoaXBwYWJsZS1kZXBsb3ktdG9rZW4tN3Nwc2oiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoic2hpcHBhYmxlLWRlcGxveSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImMyMTE3ZDhlLTNjMmQtMTFlOC05Y2NkLTQyMDEwYThhMDEyZiIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OnNoaXBwYWJsZS1kZXBsb3kifQ.ZWKrKdpK7aukTRKnB5SJwwov6PjaADT-FqSO9ZgJEg6uUVXuPa03jmqyRB20HmsTvuDabVoK7Ky7Uug7V8J9yK4oOOK5d0aRRdgHXzxZd2yO8C4ggqsr1KQsfdlU4xRWglaZGI4S31ohCApJ0MUHaVnP5WkbC4FiTZAQ5fO_LcCokapzCLQyIuD5Ksdnj5Ad2ymiLQQ71TUNccN7BMX5aM4RHmztpEHOVbElCWXwyhWr3NR1Z1ar9s5ec6iHBqfkp_s8TvxPBLyUdy9OjCWy3iLQ4Lt4qpxsjwE4NE7KioDPX2Snb6NWFK7lvldjYX4tdkpWdQHBNmqaD8CuVCRdEQ
    ca.crt:     1099 bytes
    ```

1. Now let's get the server's certificate info.  We want the values for the `certificate-authority-data` and `server` fields.

    ```shell
    $ kubectl config view --flatten --minify

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURDekNDQWZPZ0F3SUJBZ0lRZmo4VVMxNXpuaGRVbG15a3AvSVFqekFOQmdrcWhraUc5dzBCQVFzRkFEQXYKTVMwd0t3WURWUVFERXlSaVl6RTBOelV5WXkwMk9UTTFMVFExWldFdE9HTmlPUzFrWmpSak5tUXlZemd4TVRndwpIaGNOTVRnd05EQTVNVGd6TVRReVdoY05Nak13TkRBNE1Ua3pNVFF5V2pBdk1TMHdLd1lEVlFRREV5UmlZekUwCk56VXlZeTAyT1RNMUxUUTFaV0V0T0dOaU9TMWtaalJqTm1ReVl6Z3hNVGd3Z2dFaU1BMEdDU3FHU0liM0RRRUIKQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUURIVHFPV0ZXL09odDFTbDBjeUZXOGl5WUZPZHFON1lrRVFHa3E3enkzMApPUEQydUZyNjRpRXRPOTdVR0Z0SVFyMkpxcGQ2UWdtQVNPMHlNUklkb3c4eUowTE5YcmljT2tvOUtMVy96UTdUClI0ZWp1VDl1cUNwUGR4b0Z1TnRtWGVuQ3g5dFdHNXdBV0JvU05reForTC9RN2ZpSUtWU01SSnhsQVJsWll4TFQKZ1hMamlHMnp3WGVFem5lL0tsdEl4NU5neGs3U1NUQkRvRzhYR1NVRzhpUWZDNGYzTk4zUEt3Wk92SEtRc0MyZAo0ajVyc3IwazNuT1lwWDFwWnBYUmp0cTBRZTF0RzNMVE9nVVlmZjJHQ1BNZ1htVndtejJzd2xPb24wcldlRERKCmpQNGVqdjNrbDRRMXA2WXJBYnQ1RXYzeFVMK1BTT2ROSlhadTFGWWREZHZyQWdNQkFBR2pJekFoTUE0R0ExVWQKRHdFQi93UUVBd0lDQkRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFCQwpHWWd0R043SHJpV2JLOUZtZFFGWFIxdjNLb0ZMd2o0NmxlTmtMVEphQ0ZUT3dzaVdJcXlIejUrZ2xIa0gwZ1B2ClBDMlF2RmtDMXhieThBUWtlQy9PM2xXOC9IRmpMQVZQS3BtNnFoQytwK0J5R0pFSlBVTzVPbDB0UkRDNjR2K0cKUXdMcTNNYnVPMDdmYVVLbzNMUWxFcXlWUFBiMWYzRUM3QytUamFlM0FZd2VDUDNOdHJMdVBZV2NtU2VSK3F4TQpoaVRTalNpVXdleEY4cVV2SmM3dS9UWTFVVDNUd0hRR1dIQ0J2YktDWHZvaU9VTjBKa0dHZXJ3VmJGd2tKOHdxCkdsZW40Q2RjOXJVU1J1dmlhVGVCaklIYUZZdmIxejMyVWJDVjRTWUowa3dpbHE5RGJxNmNDUEI3NjlwY0o1KzkKb2cxbHVYYXZzQnYySWdNa1EwL24KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
        server: https://35.203.181.169
    name: gke_jfrog-200320_us-west1-a_cluster
    contexts:
    - context:
        cluster: gke_jfrog-200320_us-west1-a_cluster
        user: gke_jfrog-200320_us-west1-a_cluster
    name: gke_jfrog-200320_us-west1-a_cluster
    current-context: gke_jfrog-200320_us-west1-a_cluster
    kind: Config
    preferences: {}
    users:
    - name: gke_jfrog-200320_us-west1-a_cluster
    user:
        auth-provider:
        config:
            access-token: ya29.Gl2YBba5duRR8Zb6DekAdjPtPGepx9Em3gX1LAhJuYzq1G4XpYwXTS_wF4cieZ8qztMhB35lFJC-DJR6xcB02oXXkiZvWk5hH4YAw1FPrfsZWG57x43xCrl6cvHAp40
            cmd-args: config config-helper --format=json
            cmd-path: /Users/ambarish/google-cloud-sdk/bin/gcloud
            expiry: 2018-04-09T20:35:02Z
            expiry-key: '{.credential.token_expiry}'
            token-key: '{.credential.access_token}'
        name: gcp
    ```

1. Now let's put it all together into a file that we're going to call `kubeconfig.txt`.  It will look a lot like this:

    ```yaml
    apiVersion: v1
    kind: Config
    users:
    - name: svcs-acct-dply
      user:
        token: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InNoaXBwYWJsZS1kZXBsb3ktdG9rZW4tN3Nwc2oiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoic2hpcHBhYmxlLWRlcGxveSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImMyMTE3ZDhlLTNjMmQtMTFlOC05Y2NkLTQyMDEwYThhMDEyZiIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OnNoaXBwYWJsZS1kZXBsb3kifQ.ZWKrKdpK7aukTRKnB5SJwwov6PjaADT-FqSO9ZgJEg6uUVXuPa03jmqyRB20HmsTvuDabVoK7Ky7Uug7V8J9yK4oOOK5d0aRRdgHXzxZd2yO8C4ggqsr1KQsfdlU4xRWglaZGI4S31ohCApJ0MUHaVnP5WkbC4FiTZAQ5fO_LcCokapzCLQyIuD5Ksdnj5Ad2ymiLQQ71TUNccN7BMX5aM4RHmztpEHOVbElCWXwyhWr3NR1Z1ar9s5ec6iHBqfkp_s8TvxPBLyUdy9OjCWy3iLQ4Lt4qpxsjwE4NE7KioDPX2Snb6NWFK7lvldjYX4tdkpWdQHBNmqaD8CuVCRdEQ
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURDekNDQWZPZ0F3SUJBZ0lRZmo4VVMxNXpuaGRVbG15a3AvSVFqekFOQmdrcWhraUc5dzBCQVFzRkFEQXYKTVMwd0t3WURWUVFERXlSaVl6RTBOelV5WXkwMk9UTTFMVFExWldFdE9HTmlPUzFrWmpSak5tUXlZemd4TVRndwpIaGNOTVRnd05EQTVNVGd6TVRReVdoY05Nak13TkRBNE1Ua3pNVFF5V2pBdk1TMHdLd1lEVlFRREV5UmlZekUwCk56VXlZeTAyT1RNMUxUUTFaV0V0T0dOaU9TMWtaalJqTm1ReVl6Z3hNVGd3Z2dFaU1BMEdDU3FHU0liM0RRRUIKQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUURIVHFPV0ZXL09odDFTbDBjeUZXOGl5WUZPZHFON1lrRVFHa3E3enkzMApPUEQydUZyNjRpRXRPOTdVR0Z0SVFyMkpxcGQ2UWdtQVNPMHlNUklkb3c4eUowTE5YcmljT2tvOUtMVy96UTdUClI0ZWp1VDl1cUNwUGR4b0Z1TnRtWGVuQ3g5dFdHNXdBV0JvU05reForTC9RN2ZpSUtWU01SSnhsQVJsWll4TFQKZ1hMamlHMnp3WGVFem5lL0tsdEl4NU5neGs3U1NUQkRvRzhYR1NVRzhpUWZDNGYzTk4zUEt3Wk92SEtRc0MyZAo0ajVyc3IwazNuT1lwWDFwWnBYUmp0cTBRZTF0RzNMVE9nVVlmZjJHQ1BNZ1htVndtejJzd2xPb24wcldlRERKCmpQNGVqdjNrbDRRMXA2WXJBYnQ1RXYzeFVMK1BTT2ROSlhadTFGWWREZHZyQWdNQkFBR2pJekFoTUE0R0ExVWQKRHdFQi93UUVBd0lDQkRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFCQwpHWWd0R043SHJpV2JLOUZtZFFGWFIxdjNLb0ZMd2o0NmxlTmtMVEphQ0ZUT3dzaVdJcXlIejUrZ2xIa0gwZ1B2ClBDMlF2RmtDMXhieThBUWtlQy9PM2xXOC9IRmpMQVZQS3BtNnFoQytwK0J5R0pFSlBVTzVPbDB0UkRDNjR2K0cKUXdMcTNNYnVPMDdmYVVLbzNMUWxFcXlWUFBiMWYzRUM3QytUamFlM0FZd2VDUDNOdHJMdVBZV2NtU2VSK3F4TQpoaVRTalNpVXdleEY4cVV2SmM3dS9UWTFVVDNUd0hRR1dIQ0J2YktDWHZvaU9VTjBKa0dHZXJ3VmJGd2tKOHdxCkdsZW40Q2RjOXJVU1J1dmlhVGVCaklIYUZZdmIxejMyVWJDVjRTWUowa3dpbHE5RGJxNmNDUEI3NjlwY0o1KzkKb2cxbHVYYXZzQnYySWdNa1EwL24KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
        server: https://35.203.181.169
    name: self-hosted-cluster
    contexts:
     - name: kubernetes-admin@kubernetes
       context:
         user: test-user
         cluster: kubernetes-admin@kubernetes
         namespace: test-runners
    current-context: kubernetes-admin@kubernetes
    ```

1. Now let's encode it using `base64` to create a big one-line string of gibberish that we can store in GitHub Secrets.

    ```shell
    cat kubeconfig.txt | base64
    ```

1. Once it's stored in GitHub Secrets, we can use it in workflows as shown in the test or rawhide deployment jobs [here](../github/workflows).  Here's an example:

    ```yaml
    - name: Write out the kubeconfig info
      run: | 
        echo ${{ secrets.PROD_RUNNER_DEPLOY }} | base64 -d > /tmp/config

    - name: Deploy
      run: |
        kubectl apply -f deployments/rawhide-debian-buster.yml
      env:
        KUBECONFIG: /tmp/config

    - name: Remove kubeconfig info
      run: rm -f /tmp/config
    ```

## Tool cache for runners using `PersistentVolumeClaim`

These directions cover setting up a persistent volume and persistent volume claim using Azure storage.  You _will_ need to edit these a little bit to use other storage providers, but it should be called out everywhere in the example.

:warning: The default in this repository is to use the cache as read-only!  This means that an administrator _must_ cache all dependencies up front - every version of every language.  IME, this is a feature and not a bug for larger-scale enterprises, but if you'd rather, it's quite possible to change all of these to read-write.  I'd read more about [persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) and their access modes before running this with lots of users in that configuration.

1. Create file storage.  For Azure, it's a storage account with a file share - [documentation](https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction).  I created two file shares in the same storage account, one each for testing and production.
1. Store the secret to connect securely to the file storage from the k8s cluster.  For Azure storage, it looks something like what's below, where your name and key come from the access key.

    ```shell
    kubectl create secret generic azure-secret -n test-runners  \
        --from-literal=azurestorageaccountname=runnertoolcache \
        --from-literal=azurestorageaccountkey=<keyhere>
    
    kubectl create secret generic azure-secret -n runners  \
        --from-literal=azurestorageaccountname=runnertoolcache \
        --from-literal=azurestorageaccountkey=<keyhere>
    ```

1. Create two persistent volumes, one for test and one for production.  Then create a persistentvolumeclaim with "readonlymany" so that many pods can read the contents, one on each volume.  See [`runner-tool-cache.yml`](runner-tool-cache.yml) for a template and comments.

    ```shell
    kubectl apply -f runner-tool-cache.yml
    ```

1. Make sure the pods can use these shares.  Here's what this looks like in a [runner deployment](../deployments/README.md):

    ```yaml
    volumeMounts:
        - mountPath: /opt/hostedtoolcache
          name: runnertoolcache
          readOnly: true
      volumes:
        - name: runnertoolcache
          persistentVolumeClaim:
            claimName: test-tool-cache-pvc
    ```

Now let's populate the cache!  The workflow in this repository ([here](../.github/workflows/build-tool-cache.yml)) updates Azure file storage directly from a GitHub hosted runner for use in self-hosted runners.  You'll need to make this your own from that template - covering each language and version you'd like.  The example is only caching Python 3.10.  A list of more languages and features of each setup Action are available [here](https://github.com/actions?q=setup&type=all&language=&sort=).  If you need to walk this across an airgap, remove the step where it connects and uploads to Azure and download the tarball to do with what you need to. :-)
