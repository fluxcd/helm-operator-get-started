# Managing Helm releases the GitOps way

**What is GitOps?**

GitOps is a way to do Continuous Delivery, it works by using Git as a source of truth for declarative infrastructure and workloads. For Kubernetes this means using `git push` instead of `kubectl create/apply` or `helm install/upgrade`.

In a traditional CICD pipeline, CD is an implementation extension powered by the continuous integration tooling to promote build artifacts to production. In the GitOps pipeline model, any change to production must be committed in source control (preferable via a pull request) prior to being applied on the cluster. This way rollback and audit logs are provided by Git. If the entire production state is under version control and described in a single Git repository, when disaster strikes, the whole infrastructure can be quickly restored from that repository.

To better understand the benefits of this approach to CD and what are the differences between GitOps and Infrastructure-as-Code tools, head to Weaveworks website and read [GitOps - What you need to know](https://www.weave.works/technologies/gitops/) article.

In order to apply the GitOps pipeline model to Kubernetes you need three things: 

* a Git repository with your workloads definitions in YAML format, Helm charts and any other Kubernetes custom resource that defines your cluster desired state (I will refer to this as the *config* repository)
* a container registry where your CI system pushes immutable images (no *latest* tags, use *semantic versioning* or git *commit sha*)
* an operator that runs in your cluster and does a two-way synchronization:
    * watches the registry for new image releases and based on deployment policies updates the workload definitions with the new image tag and commits the changes to the config repository 
    * watches for changes in the config repository and applies them to your cluster

![gitops](https://github.com/stefanprodan/k8s-podinfo/blob/master/docs/diagrams/flux-helm.png)

Prerequisites:
 - fork this repository 
 - install Helm and Tiller
 - install Weave Flux

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
--set git.url=ssh://git@github.com/stefanprodan/weave-flux-helm-demo \
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


## <a name="help"></a>Getting Help

If you have any questions about this Weave Flux Helm Demo:

- Checkout the weaveworks [helm integration guide](https://github.com/weaveworks/flux/blob/master/site/helm/helm-integration.md)
- Invite yourself to the <a href="https://weaveworks.github.io/community-slack/" target="_blank">Weave community</a> slack.
- Ask a question on the [#flux](https://weave-community.slack.com/messages/flux/) slack channel.
- Join the <a href="https://www.meetup.com/pro/Weave/"> Weave User Group </a> and get invited to online talks, hands-on training and meetups in your area.
- Send an email to <a href="mailto:weave-users@weave.works">weave-users@weave.works</a>
- <a href="https://github.com/stefanprodan/weave-flux-helm-demo/issues/new">File an issue.</a>

Your feedback is always welcome!
