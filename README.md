# OpenUEM Helm Chart

A Helm chart for deploying [OpenUEM](https://github.com/open-uem) — Open Unified Endpoint Management — on Kubernetes.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x
- [CloudNativePG](https://cloudnative-pg.io/) operator — only when `cnpg.enabled=true`
- [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/) with the `crd` source enabled — only when `externalDns.enabled=true`

## Installation

### From OCI Registry (GitHub Packages)

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1
```

### From Local Source

```bash
helm dependency update .
helm install openuem .
```

## Architecture

The chart deploys the following components:

| Component | Kind | Description |
|-----------|------|-------------|
| **cert-init** | Job | One-shot job that generates all TLS certificates and stores them in a shared PVC |
| **postgresql** | StatefulSet | Optional built-in PostgreSQL 17 instance |
| **cnpg cluster** | CloudNativePG `Cluster` | Optional operator-managed PostgreSQL cluster (opt-in, replaces the built-in StatefulSet) |
| **console** | Deployment | Web UI for endpoint management |
| **ocsp-responder** | Deployment | OCSP responder for certificate validation |
| **notification-worker** | Deployment | Worker that processes notification events via NATS |
| **cert-manager-worker** | Deployment | Worker that handles certificate lifecycle operations |
| **agents-worker** | Deployment | Worker that manages agent communication |
| **NATS** | Subchart | Message broker (deployed via the official NATS Helm chart) |
| **dns-endpoint** | ExternalDNS `DNSEndpoint` | Optional DNS records for the console/auth hostnames (opt-in) |

All components share a certificate PVC (`openuem-certs`) populated by the cert-init job and wait for certificates to be ready before starting.

## Configuration

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry prefix | `""` |
| `global.imagePullSecrets` | Global image pull secrets | `[]` |

### Organization

Used during certificate generation.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `organization.name` | Organization name | `"OpenUEM"` |
| `organization.province` | Province / state | `"Valladolid"` |
| `organization.locality` | City | `"Valladolid"` |
| `organization.address` | Street address | `""` |
| `organization.country` | ISO country code | `"ES"` |
| `organization.domain` | Base domain for service hostnames | `"openuem.example"` |

### Certificate Initialization

| Parameter | Description | Default |
|-----------|-------------|---------|
| `certInit.image.repository` | Image repository | `openuem/openuem-cert-manager` |
| `certInit.image.tag` | Image tag | `"latest"` |
| `certInit.image.pullPolicy` | Image pull policy | `Always` |
| `certInit.reverseProxyServer` | Reverse proxy hostname (optional) | `""` |
| `certInit.backoffLimit` | Job retry limit | `3` |
| `certInit.ttlSecondsAfterFinished` | Auto-cleanup delay | `300` |
| `certInit.resources` | Resource requests/limits | `{}` |
| `certInit.persistence.storageClass` | PVC storage class | `""` |
| `certInit.persistence.size` | PVC size | `256Mi` |
| `certInit.persistence.accessModes` | PVC access modes | `[ReadWriteOnce]` |
| `certInit.persistence.claimName` | Fixed PVC name (used by NATS subchart) | `openuem-certs` |

### PostgreSQL (built-in)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy built-in PostgreSQL | `true` |
| `postgresql.image.repository` | Image repository | `postgres` |
| `postgresql.image.tag` | Image tag | `"17"` |
| `postgresql.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `postgresql.auth.username` | Database user | `openuem` |
| `postgresql.auth.password` | Database password | `openuem` |
| `postgresql.auth.database` | Database name | `openuem` |
| `postgresql.auth.existingSecret` | Existing Secret with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` keys | `""` |
| `postgresql.port` | PostgreSQL port | `5432` |
| `postgresql.persistence.enabled` | Enable persistent storage | `true` |
| `postgresql.persistence.storageClass` | Storage class | `""` |
| `postgresql.persistence.size` | Volume size | `10Gi` |
| `postgresql.persistence.accessModes` | Access modes | `[ReadWriteOnce]` |
| `postgresql.resources` | Resource requests/limits | `{}` |

### CloudNativePG cluster (opt-in)

Instead of the built-in StatefulSet, the chart can create a [CloudNativePG](https://cloudnative-pg.io/) `Cluster` and wire the application to it. Requires the CloudNativePG operator to be installed in the cluster. Set `postgresql.enabled=false` when enabling this — the two are mutually exclusive and the chart fails to render if both are on.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cnpg.enabled` | Create a CloudNativePG `Cluster` | `false` |
| `cnpg.name` | Cluster name (default: `<release-fullname>-pg`) | `""` |
| `cnpg.instances` | Number of PostgreSQL instances | `1` |
| `cnpg.imageName` | CloudNativePG PostgreSQL image | `ghcr.io/cloudnative-pg/postgresql:17` |
| `cnpg.database` | Database created by the initdb bootstrap | `openuem` |
| `cnpg.owner` | Owner role of that database | `openuem` |
| `cnpg.existingSecret` | Existing Secret with `username`/`password` keys for the owner (default: operator-generated `<cluster>-app`) | `""` |
| `cnpg.enableSuperuserAccess` | Generate a `postgres` superuser Secret | `false` |
| `cnpg.primaryUpdateStrategy` | Rolling update strategy for the primary | `unsupervised` |
| `cnpg.storage.size` | Data volume size | `10Gi` |
| `cnpg.storage.storageClass` | Data volume storage class | `""` |
| `cnpg.walStorage.enabled` | Use a dedicated WAL volume | `false` |
| `cnpg.walStorage.size` | WAL volume size | `2Gi` |
| `cnpg.walStorage.storageClass` | WAL volume storage class | `""` |
| `cnpg.parameters` | PostgreSQL server parameters (`spec.postgresql.parameters`) | `{}` |
| `cnpg.monitoring.enablePodMonitor` | Create a Prometheus `PodMonitor` | `false` |
| `cnpg.resources` | Resource requests/limits | `{}` |
| `cnpg.affinity` | CloudNativePG affinity settings (`spec.affinity`) | `{}` |
| `cnpg.backup` | Passed through to `spec.backup` (e.g. `barmanObjectStore`) | `{}` |
| `cnpg.extraSpec` | Extra fields merged into `spec` | `{}` |
| `cnpg.annotations` | Cluster annotations | `{}` |
| `cnpg.labels` | Extra cluster labels | `{}` |

The chart points `DATABASE_URL` at the cluster's `<cluster>-rw` Service and reads the owner username/password from `cnpg.existingSecret` (or the operator-generated `<cluster>-app` Secret) via `secretKeyRef`, composing the URL at container start. Nothing needs to be set under `externalDatabase`.

```yaml
postgresql:
  enabled: false

cnpg:
  enabled: true
  instances: 3
  storage:
    size: 20Gi
    storageClass: fast-ssd
  parameters:
    max_connections: "200"
```

### External Database

Used when `postgresql.enabled=false`.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalDatabase.host` | Database host | `""` |
| `externalDatabase.port` | Database port | `5432` |
| `externalDatabase.username` | Database user | `""` |
| `externalDatabase.password` | Database password | `""` |
| `externalDatabase.database` | Database name | `""` |
| `externalDatabase.url` | Full connection URL (used when `existingSecret` is unset) | `""` |
| `externalDatabase.existingSecret` | Existing Secret with `username`/`password` keys (CNPG-compatible) | `""` |
| `externalDatabase.existingSecretUsernameKey` | Username key inside `existingSecret` | `username` |
| `externalDatabase.existingSecretPasswordKey` | Password key inside `existingSecret` | `password` |

### OCSP Responder

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ocspResponder.image.repository` | Image repository | `openuem/openuem-ocsp-responder` |
| `ocspResponder.image.tag` | Image tag | `"latest"` |
| `ocspResponder.image.pullPolicy` | Image pull policy | `Always` |
| `ocspResponder.port` | Container port | `8000` |
| `ocspResponder.hostname` | Override hostname (default: `<release>-ocsp-responder`) | `""` |
| `ocspResponder.replicaCount` | Replica count | `1` |
| `ocspResponder.service.type` | Service type | `ClusterIP` |
| `ocspResponder.service.port` | Service port | `8000` |
| `ocspResponder.service.nodePort` | NodePort (when type=NodePort) | `null` |
| `ocspResponder.resources` | Resource requests/limits | `{}` |

### NATS

The chart includes the [official NATS Helm chart](https://github.com/nats-io/k8s) as a subchart with JetStream and TLS enabled by default.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nats.enabled` | Deploy NATS subchart | `true` |
| `natsConfig.port` | NATS client port | `4433` |
| `natsConfig.hostname` | Override NATS hostname (default: `<release>-nats`) | `""` |

See the [NATS chart documentation](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) for the full set of subchart values under the `nats` key.

### Workers

All workers share the same image and can be individually enabled/disabled.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `workers.image.repository` | Image repository | `openuem/openuem-worker` |
| `workers.image.tag` | Image tag | `"latest"` |
| `workers.image.pullPolicy` | Image pull policy | `Always` |
| `workers.notification.enabled` | Enable notification worker | `true` |
| `workers.notification.replicaCount` | Replica count | `1` |
| `workers.notification.resources` | Resource requests/limits | `{}` |
| `workers.certManager.enabled` | Enable cert-manager worker | `true` |
| `workers.certManager.replicaCount` | Replica count | `1` |
| `workers.certManager.resources` | Resource requests/limits | `{}` |
| `workers.agents.enabled` | Enable agents worker | `true` |
| `workers.agents.replicaCount` | Replica count | `1` |
| `workers.agents.resources` | Resource requests/limits | `{}` |

### Console

| Parameter | Description | Default |
|-----------|-------------|---------|
| `console.image.repository` | Image repository | `openuem/openuem-console` |
| `console.image.tag` | Image tag | `"latest"` |
| `console.image.pullPolicy` | Image pull policy | `Always` |
| `console.port` | Main console port | `1323` |
| `console.authPort` | Auth endpoint port | `1324` |
| `console.hostname` | Override hostname (default: `console.<domain>`) | `""` |
| `console.jwtKey` | JWT signing key | `"averylongsecret"` |
| `console.existingSecret` | Existing Secret with a `JWT_KEY` key | `""` |
| `console.reverseProxyAuthPort` | Reverse proxy auth port | `""` |
| `console.reverseProxyServer` | Reverse proxy server | `""` |
| `console.replicaCount` | Replica count | `1` |
| `console.service.type` | Service type | `ClusterIP` |
| `console.service.port` | Service port | `1323` |
| `console.service.authPort` | Auth service port | `1324` |
| `console.resources` | Resource requests/limits | `{}` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Host rules **(required** when enabled**)** | `[]` |
| `ingress.tls` | TLS configuration | `[]` |

### Traefik IngressRoute

For clusters using [Traefik](https://doc.traefik.io/traefik/) as the ingress controller, the chart can create a native `IngressRoute` CRD instead of a standard Ingress.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `traefik.ingressRoute.enabled` | Create Traefik IngressRoutes | `false` |
| `traefik.ingressRoute.apiVersion` | IngressRoute CRD API version (e.g. `traefik.containo.us/v1alpha1` for legacy installs) | `traefik.io/v1alpha1` |
| `traefik.ingressRoute.annotations` | Annotations applied to both IngressRoutes | `{}` |
| `traefik.ingressRoute.entryPoints` | Traefik entrypoints to listen on | `[websecure]` |
| `traefik.ingressRoute.console.host` | Host name for the console UI, routed to `console.service.port` **(required** when enabled**)** | `""` |
| `traefik.ingressRoute.console.tls.certResolver` | Cert resolver for the console route (e.g. `"letsencrypt"`) | `""` |
| `traefik.ingressRoute.console.tls.secretName` | Existing TLS Secret for the console route (mutually exclusive with `certResolver`) | `""` |
| `traefik.ingressRoute.auth.host` | Host name for the auth endpoint, routed to `console.service.authPort` **(required** when enabled**)** | `""` |
| `traefik.ingressRoute.auth.tls.certResolver` | Cert resolver for the auth route (e.g. `"letsencrypt"`) | `""` |
| `traefik.ingressRoute.auth.tls.secretName` | Existing TLS Secret for the auth route (mutually exclusive with `certResolver`) | `""` |

### ExternalDNS (opt-in)

The chart can publish DNS records for its hostnames through a [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/) `DNSEndpoint` resource. Requires ExternalDNS to be installed with the `crd` source enabled.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalDns.enabled` | Create a `DNSEndpoint` | `false` |
| `externalDns.target` | IP or hostname the records resolve to **(required** when enabled**)** | `""` |
| `externalDns.recordType` | `A` for IP targets, `CNAME` for hostname targets | `A` |
| `externalDns.recordTTL` | Record TTL in seconds | `300` |
| `externalDns.cloudflareProxied` | Cloudflare-only: proxy (orange-cloud) the record. Ignored by other providers | `false` |
| `externalDns.hosts` | Hostnames to publish. When empty, derived from the Traefik IngressRoute hosts and `ingress.hosts` | `[]` |

Hostnames are resolved in this order: `externalDns.hosts` when set, otherwise `traefik.ingressRoute.console.host` + `traefik.ingressRoute.auth.host` (when the IngressRoute is enabled) plus every `ingress.hosts[].host` (when ingress is enabled). Duplicates are removed, and rendering fails if the resolved list is empty.

```yaml
traefik:
  ingressRoute:
    enabled: true
    console:
      host: console.example.com
    auth:
      host: auth.example.com

externalDns:
  enabled: true
  target: 203.0.113.10
```

### ServiceAccount

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | Override name (default: release fullname) | `""` |
| `serviceAccount.annotations` | Annotations | `{}` |

## Using Existing Secrets

For production deployments you will typically manage secrets externally (e.g. Sealed Secrets, External Secrets Operator, Vault). The chart supports pointing to pre-existing Kubernetes Secrets instead of having the chart create them.

There are three credential groups, each with its own `existingSecret` field:

### PostgreSQL credentials

```yaml
postgresql:
  auth:
    existingSecret: "my-pg-secret"
```

The referenced Secret must contain these keys:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`

### Database credentials (CNPG-compatible)

```yaml
externalDatabase:
  host: my-cluster-rw
  port: 5432
  database: app
  existingSecret: my-cluster-app
```

The referenced Secret must contain:

- `username`
- `password`

Defaults match secrets produced by [CloudNativePG](https://cloudnative-pg.io/) (basic-auth type with `username`/`password` keys). Override the key names with `externalDatabase.existingSecretUsernameKey` and `externalDatabase.existingSecretPasswordKey` if your secret uses different names.

The chart pulls username and password from the secret via `secretKeyRef` and composes `DATABASE_URL` at container start using `host`, `port`, and `database` from values. Passwords containing URL-reserved characters (`@`, `:`, `/`, `?`, `#`, `%`) must be URL-encoded inside the secret.

### JWT key

```yaml
console:
  existingSecret: "my-jwt-secret"
```

The referenced Secret must contain:

- `JWT_KEY`

When an `existingSecret` is set, the chart skips creating those keys in its managed Secret and all `secretKeyRef` references point to the user-provided Secret name. If all three are set, the chart-managed Secret is not created at all.

You can mix and match — for example, externalize only the database URL while letting the chart manage the rest:

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set externalDatabase.existingSecret=my-db-secret
```

## Examples

### Minimal install (all defaults)

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1
```

### External database

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set postgresql.enabled=false \
  --set externalDatabase.url="postgres://user:pass@db.example.com:5432/openuem"
```

### External database with existing Secret (CNPG)

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set postgresql.enabled=false \
  --set externalDatabase.host=my-cluster-rw \
  --set externalDatabase.database=app \
  --set externalDatabase.existingSecret=my-cluster-app
```

### CloudNativePG-managed database

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set postgresql.enabled=false \
  --set cnpg.enabled=true \
  --set cnpg.instances=3
```

### With ExternalDNS records

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set externalDns.enabled=true \
  --set externalDns.target=203.0.113.10 \
  --set "externalDns.hosts={console.example.com,auth.example.com}"
```

### All secrets externalized

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set postgresql.auth.existingSecret=my-pg-secret \
  --set externalDatabase.existingSecret=my-db-secret \
  --set console.existingSecret=my-jwt-secret
```

### With Traefik IngressRoute

```yaml
traefik:
  ingressRoute:
    enabled: true
    entryPoints:
      - websecure
    console:
      host: console.example.com
      tls:
        secretName: console-tls
    auth:
      host: auth.example.com
      tls:
        secretName: auth-tls
```

### With ingress

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: console.example.com
      paths:
        - path: /
          pathType: Prefix
          port: 1323
    - host: auth.example.com
      paths:
        - path: /
          pathType: Prefix
          port: 1324
  tls:
    - secretName: console-tls
      hosts:
        - console.example.com
        - auth.example.com
```

## Known Issues

### Login redirect fails when using port-forward

When accessing the console via `kubectl port-forward`, the login button may not redirect properly after authentication because the redirect URL uses the configured hostname instead of `localhost`.

**Workaround:** After clicking the login button, simply refresh the browser. The homepage will load correctly with your authenticated session.
