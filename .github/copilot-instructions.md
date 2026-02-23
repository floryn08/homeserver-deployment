# Homeserver Deployment - AI Agent Guide

## Architecture Overview

This is a Kubernetes-based homeserver deployment using **ArgoCD's App of Apps pattern** with Helm charts. The repository manages 7 service categories (ai-services, core-services, game-servers, home-automation, media-management, monitoring, utility-services), each deployed as a separate namespace.

**Three-tier hierarchy:**
1. `charts/master-app/` - Root ArgoCD Application that bootstraps everything
2. `charts/app-of-apps/{category}/` - Category-level Helm charts that generate ArgoCD Applications
3. `charts/apps/{category}/{service}/` - Individual service Helm charts

**Critical services deployment order** (see [README.md](README.md)):
1. Vault (secrets management)
2. Vault Secrets Operator (secret sync to k8s)
3. Homelab ALM (automation/lifecycle management)
4. ArgoCD (GitOps controller)
5. Apply `charts/master-app.yaml` to bootstrap remaining services

## Key Conventions

### Helm Chart Structure
Every service in `charts/apps/` follows this template structure:
- `values.yaml` - Service configuration (image, namespace, host.subdomain, secrets.path, storage.appdataBasePath, service.ports)
- `templates/deployment.yaml` - Standard deployment with Reloader annotation (`reloader.stakater.com/auto: "true"`)
- `templates/pv.yaml` + `pvc.yaml` - Local persistent volumes using `storageClass: manual`
- `templates/ingress-request.yaml` - Traefik IngressRoute with cert-manager TLS
- `templates/certificate-request.yaml` - cert-manager Certificate
- `templates/configmap.yaml` - Environment variables from values

**Storage pattern:** All apps use host paths at `/srv/appdata/{namespace}/{service}/` mounted via PV/PVC. Media services additionally mount `/mnt/hdd` and `/mnt/hdd12tb` as hostPath volumes.

### App-of-Apps Pattern
Each category chart in `charts/app-of-apps/{category}/templates/` contains YAML files generating ArgoCD Applications. Example from [core-services/templates/argo-cd.yaml](charts/app-of-apps/core-services/templates/argo-cd.yaml):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-cd
  namespace: {{ .Values.argocdNamespace }}
spec:
  source:
    path: {{ .Values.argoCd.path }}  # points to charts/apps/core-services/argo-cd
    repoURL: {{ .Values.repoUrl }}
    helm:
      valueFiles: [values.yaml]
```

### Secrets Management
- Vault is the source of truth for all secrets (domain names, API keys, passwords)
- Services reference secrets via `secrets.path` in values.yaml (e.g., `kv/data/domains`)
- Vault Secrets Operator syncs Vault secrets to Kubernetes Secret resources
- Each namespace has `VaultConnection` and `VaultAuth` (ServiceAccount-based K8s auth)

### Namespace Strategy
- `core-services` - Infrastructure (ArgoCD, Vault, Traefik, Authentik, PostgreSQL, cert-manager)
- `ai-services` - AI/LLM workloads (Ollama, Open WebUI, ComfyUI)
- `media-management` - Media stack (Plex, Jellyfin, *arr apps, qBittorrent)
- `game-servers` - Game hosting (Minecraft, Valheim, ROMM)
- `home-automation` - IoT/smart home (Home Assistant)
- `utility-services` - General tools (Paperless, Vaultwarden, Homepage, Mealie)
- `monitoring` - Observability (Grafana, Prometheus) - currently disabled

**Special case:** `game-servers` has `syncPolicy.automated.prune: false` in [master-app/values.yaml](charts/master-app/values.yaml) to prevent accidental world deletion.

## Key Files

- [charts/master-app.yaml](charts/master-app.yaml) - Bootstrap ArgoCD Application (create this manually)
- [charts/master-app/values.yaml](charts/master-app/values.yaml) - Global config (repoUrl, namespaces, enabled toggles)
- [renovate.json](renovate.json) - Automated dependency updates with Docker image version pinning patterns
- [cleanup-images.sh](cleanup-images.sh) - K3s maintenance script (`kubectl ssh` to nodes, runs `k3s crictl rmi --prune`)
- [compose/compose.yml](compose/compose.yml) - Separate docker-compose deployment for critical home-automation services (MQTT, Home Assistant, Zigbee2MQTT) running on a dedicated mini PC for stability

## Development Workflows

**Adding a new service:**
1. Copy existing service chart from `charts/apps/{category}/` as template
2. Update `values.yaml` (image, subdomain, secrets, storage paths, ports)
3. Add ArgoCD Application YAML to `charts/app-of-apps/{category}/templates/`
4. Update `charts/app-of-apps/{category}/values.yaml` with service.path entry
5. ArgoCD auto-syncs and deploys (or use `argocd app sync`)

**Manual Helm operations** (avoid unless bootstrapping):
```bash
helm dep update ./charts/apps/{category}/{service}
helm upgrade {service} ./charts/apps/{category}/{service} --install --namespace {namespace} --create-namespace
```

**Debugging deployments:**
- Check ArgoCD UI for sync status and errors
- Verify Vault secret paths match `secrets.path` in values.yaml
- Confirm PV/PVC creation: `kubectl get pv,pvc -n {namespace}`
- Check Reloader for automatic restarts on configmap/secret changes

## Project-Specific Patterns

- **LinuxServer.io images:** Most media services use `linuxserver/{app}` images (see renovate.json versioning regex)
- **Ingress:** All services use Traefik IngressRoutes (not k8s Ingress), subdomain-based routing
- **GPU workloads:** nvidia-gpu-operator in core-services enables GPU scheduling for AI services
- **No HorizontalPodAutoscaler:** All deployments use `replicas: 1` (homelab scale)
- **Health checks:** Most services use `livenessProbe` with curl to service endpoint (e.g., radarr uses `/ping`)

## Renovate Configuration

Renovate automatically updates Docker image tags with service-specific rules:
- LinuxServer/Hotio images use custom regex versioning
- Filtering unwanted versions (e.g., qbittorrent excludes non-semver tags)
- Different update schedules for core-services (minor/patch) vs media-management (all updates)
