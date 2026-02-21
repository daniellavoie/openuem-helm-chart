# OpenUEM Helm Chart

A Helm chart for deploying [OpenUEM](https://github.com/open-uem) — Open Unified Endpoint Management — on Kubernetes.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x

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
| **console** | Deployment | Web UI for endpoint management |
| **ocsp-responder** | Deployment | OCSP responder for certificate validation |
| **notification-worker** | Deployment | Worker that processes notification events via NATS |
| **cert-manager-worker** | Deployment | Worker that handles certificate lifecycle operations |
| **agents-worker** | Deployment | Worker that manages agent communication |
| **NATS** | Subchart | Message broker (deployed via the official NATS Helm chart) |

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

### External Database

Used when `postgresql.enabled=false`.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalDatabase.host` | Database host | `""` |
| `externalDatabase.port` | Database port | `5432` |
| `externalDatabase.username` | Database user | `""` |
| `externalDatabase.password` | Database password | `""` |
| `externalDatabase.database` | Database name | `""` |
| `externalDatabase.url` | Full connection URL (takes precedence) | `""` |
| `externalDatabase.existingSecret` | Existing Secret with a `DATABASE_URL` key | `""` |

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
| `traefik.ingressRoute.enabled` | Create a Traefik IngressRoute | `false` |
| `traefik.ingressRoute.annotations` | Annotations | `{}` |
| `traefik.ingressRoute.entryPoints` | Traefik entrypoints to listen on | `[websecure]` |
| `traefik.ingressRoute.routes` | Route definitions (host + port) **(required** when enabled**)** | `[]` |
| `traefik.ingressRoute.tls.certResolver` | Traefik cert resolver (e.g. `"letsencrypt"`) | `""` |
| `traefik.ingressRoute.tls.secretName` | Existing TLS Secret (mutually exclusive with certResolver) | `""` |

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

### Database URL

```yaml
externalDatabase:
  existingSecret: "my-db-secret"
```

The referenced Secret must contain:

- `DATABASE_URL` — a full PostgreSQL connection string (e.g. `postgres://user:pass@host:5432/dbname`)

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

### External database with existing Secret

```bash
helm install openuem oci://ghcr.io/daniellavoie/helm-charts/openuem --version 0.0.1-alpha.1 \
  --set postgresql.enabled=false \
  --set externalDatabase.existingSecret=my-db-secret
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
    routes:
      - host: console.example.com
        port: 1323
      - host: auth.example.com
        port: 1324
    tls:
      certResolver: letsencrypt
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
