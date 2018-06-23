# GitOps with Helm and Weave Flux

Automate Helm releases with Weave Flux. 

![gitops](https://github.com/stefanprodan/k8s-podinfo/blob/master/docs/diagrams/flux-helm.png)

Prerequisites:
 - fork this repository 
 - install Helm and Tiller
 - install Weave Flux

### Install Helm

Install Helm CLI:

On MacOS:

```bash
brew install kubernetes-helm
```

On Linux:

- Download the [latest release](https://github.com/kubernetes/helm/releases/latest)
- unpack the tarball and put the binary in your `$PATH`

Create a service account and a cluster role binding for Tiller:

```bash
kubectl -n kube-system create sa tiller

kubectl create clusterrolebinding tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller 
```

Deploy Tiller in `kube-system` namespace:

```bash
helm init --skip-refresh --upgrade --service-account tiller
```

### Install Weave Flux 

Add the Weave Flux chart repo:

```bash
helm repo add weaveworks https://weaveworks.github.io/flux
```

Install Weave Flux and its Helm Operator by specifying your fork URL 
(replace `stefanprodan` with your GitHub username): 

```bash
helm install --name flux \
--set helmOperator.create=true \
--set git.url=git@github.com:stefanprodan/weave-flux-helm-demo \
--set git.chartsPath=charts \
--namespace flux \
weaveworks/flux
```

You can connect Weave Flux to Weave Cloud using a service token:

```bash
helm install --name flux \
--set token=YOUR_WEAVE_CLOUD_SERVICE_TOKEN \
--set helmOperator.create=true \
--set git.url=git@github.com:stefanprodan/weave-flux-helm-demo \
--set git.chartsPath=charts \
--namespace flux \
weaveworks/flux
```

Note that Flux Helm Operator works with Kubernetes 1.9 or newer.

### Setup Git sync

At startup Flux generates a SSH key and logs the public key. 
Find the SSH public key with:

```bash
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2
```

In order to sync your cluster state with git you need to copy the public key and 
create a **deploy key** with **write access** on your GitHub repository.

Open GitHub, navigate to your fork, go to _Setting > Deploy keys_ click on _Add deploy key_, check 
_Allow write access_, paste the Flux public key and click _Add key_.

After a couple of seconds Flux will create the `test` namespace and will install a Helm release 
for each resource inside the `releases` dir.

```bash
helm list --namespace test
NAME    	REVISION	UPDATED                 	STATUS  	CHART          	NAMESPACE
backend 	1       	Tue Apr 24 01:28:22 2018	DEPLOYED	podinfo-0.1.0  	test     
cache   	1       	Tue Apr 24 01:28:23 2018	DEPLOYED	memcached-2.0.1	test     
database	1       	Tue Apr 24 01:28:21 2018	DEPLOYED	mongodb-0.4.27 	test     
frontend	1       	Tue Apr 24 01:28:22 2018	DEPLOYED	podinfo-0.1.0  	test     
```

## <a name="help"></a>Getting Help

If you have any questions about this Weave Flux Helm Demo:

- Checkout the weaveworks [helm integration guide](https://github.com/weaveworks/flux/blob/master/site/helm/helm-integration.md)
- Invite yourself to the <a href="https://weaveworks.github.io/community-slack/" target="_blank">Weave community</a> slack.
- Ask a question on the [#flux](https://weave-community.slack.com/messages/flux/) slack channel.
- Join the <a href="https://www.meetup.com/pro/Weave/"> Weave User Group </a> and get invited to online talks, hands-on training and meetups in your area.
- Send an email to <a href="mailto:weave-users@weave.works">weave-users@weave.works</a>
- <a href="https://github.com/stefanprodan/weave-flux-helm-demo/issues/new">File an issue.</a>

Your feedback is always welcome!