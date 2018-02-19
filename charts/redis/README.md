# Redis

This chart bootstraps a [Redis](https://github.com/bitnami/bitnami-docker-redis) deployment in standalone mode without disk persistence.

## Configuration

The following tables lists the configurable parameters of the Redis chart and their default values.

|           Parameter           |                Description                       |           Default            |
|-------------------------------|--------------------------------------------------|------------------------------|
| `image`                       | Redis image                                      | `bitnami/redis:{VERSION}`    |
| `imagePullPolicy`             | Image pull policy                                | `IfNotPresent`               |
| `service.type`                | Kubernetes Service type                          | `ClusterIP`                  |
| `usePassword`                 | Use password                                     | `false`                      |
| `redisPassword`               | Redis password                                   | Randomly generated           |
| `flags`                       | Redis command-line flags                         | `--appendonly no`            |
| `maxmemory`                   | Redis maxmemory                                  | `256mb`                      |
| `eviction`                    | Redis eviction policy                            | `allkeys-lru`                |
| `resources.requests`          | CPU/Memory resource requests                     | Memory: `64Mi`, CPU: `10m`  |
| `resources.limits`            | CPU/Memory resource limits                       | Memory: `512Mi`              |
| `metrics.enabled`             | Start a side-car Prometheus exporter             | `true`                       |
| `nodeSelector`                | Node labels for pod assignment                   | {}                           |
| `tolerations`                 | Toleration labels for pod assignment             | []                           |

### Install

Create a `cache` release:

```bash
$ helm install upgrade --install --wait cache \
  --namespace default \
  --set maxmemory=512mb \
  --set eviction=allkeys-lru \
  --set resources.limits.memory=1Gi \
  --set usePassword=true \
  --set redisPassword=secretpassword \
    ./charts/stable/redis
```

### Test

Run connectivity tests for the Redis server and the exporter sidecar:

```bash
helm test --cleanup cache
```

### Uninstall

Delete the `cache` release:

```bash
helm delete --purge cache
```


