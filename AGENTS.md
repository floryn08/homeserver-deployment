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
- `templates/deployment.yaml` - Standard deployment with pod-template checksums for consumed ConfigMaps
- `templates/pv.yaml` + `pvc.yaml` - Local persistent volumes using `storageClass: manual`
- `templates/ingress-request.yaml` - Traefik IngressRoute with cert-manager TLS
- `templates/certificate-request.yaml` - cert-manager Certificate
- `templates/configmap.yaml` - Environment variables from values

**Storage pattern:** All apps use host paths at `/srv/appdata/{namespace}/{service}/` mounted via PV/PVC. Media services additionally mount `/mnt/hdd` and `/mnt/hdd12tb` as hostPath volumes.

### Chart Authoring Rules
- Start from the closest existing chart in the same category and preserve its patterns for values, dependencies, storage, labels, ingress, dashboard registration, and Homepage registration. Do not add optional configuration merely because an upstream chart supports it.
- Before writing a local workload for a supporting service, search this repository for an existing Helm dependency for that role. If one exists, use the same dependency, versioning approach, and minimal values shape. Run `helm dependency build` so `Chart.lock` and the vendored archive match `Chart.yaml`.
- Use upstream components only for their intended deployment model. Confirm whether an image or chart is single-node, replicated, or HA before choosing it; default to the simplest model that satisfies the requested service unless redundancy is explicitly required.
- Confirm the product architecture from official documentation. Do not model an extension, plugin, or add-on as an independent backing service when it runs inside another engine; provision its actual underlying engine correctly.
- Keep `values.yaml` and handwritten Kubernetes templates in block-style YAML. Do not use flow-style maps or lists such as `{key: value}` or `[item]`; Helm delimiters and compact shell arguments are the only exceptions when they materially improve correctness.
- Follow the repository's existing image convention for the component category. Do not introduce a digest, tag override, image override, custom configuration, persistence, resource requests, or resource limits unless the user requested it or the closest existing chart requires it. PVC storage requests remain required Kubernetes storage declarations, not workload resource requests.
- After rendering, inspect the generated workload names, service DNS names, persistent storage mode, image references, replicas, and resource settings. Validate the service chart, its app-of-apps chart, and any chart changed for registration with `helm lint`, `helm template`, and `git diff --check`.

### Configuration and Secret Rollouts
- Do not add Reloader, `reloader.stakater.com` annotations, or another general-purpose restart controller.
- Every Deployment or StatefulSet that consumes a chart-rendered ConfigMap must include one checksum annotation per consumed ConfigMap under `spec.template.metadata.annotations`. This is mandatory even for ConfigMaps mounted as volumes.
- Use distinct annotation keys when a workload consumes multiple ConfigMaps:
  ```yaml
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    checksum/services: {{ include (print $.Template.BasePath "/services-configmap.yaml") . | sha256sum }}
  ```
- ConfigMap checksums trigger rollouts only when Helm renders and ArgoCD syncs the changed chart. Do not rely on out-of-band ConfigMap edits to restart workloads.
- Every `VaultStaticSecret` whose destination Secret is consumed by a workload that cannot reload secrets dynamically must declare that exact controller in `spec.rolloutRestartTargets`:
  ```yaml
  rolloutRestartTargets:
    - kind: Deployment
      name: {{ .Release.Name }}
  ```
- Add the target to every Vault secret custom resource consumed by the workload. Use the actual controller kind and rendered name; supported kinds are `Deployment`, `DaemonSet`, `StatefulSet`, and `argo.Rollout`.
- Do not add rollout targets for backup-only Secrets consumed exclusively by CronJobs; CronJobs are unsupported targets and each new Job reads the current Secret.

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
- Vault-backed workloads that require a restart use `spec.rolloutRestartTargets` on their `VaultStaticSecret`
- When wiring secrets into Deployments, prefer explicit `env[].valueFrom.secretKeyRef` entries over broad `envFrom.secretRef` imports so each environment variable shows the exact Kubernetes Secret name and key it consumes.

### Authentik SSO and Application Access
- Keep Authentik Applications and OAuth2/OIDC or proxy Providers manually managed. Do not put OAuth client secrets in Git or in the Authentik Blueprint ConfigMap; store their client ID/secret with the application's existing Vault secret path and sync them with a `VaultStaticSecret`.
- Every new Authentik Application must have explicit access control. Update `charts/apps/core-services/authentik/templates/access-control-blueprint-configmap.yaml` in the same change to add an `app-<slug>-users` group and a group `policybinding` for the application slug. Authentik applications are deliberately not automatically discovered or made accessible by default.
- If the application has separate in-application roles, retain them as child groups of `app-<slug>-users`. This grants application access to role holders while the downstream application continues to decide its own permissions.
- Configure the application workload with the provider discovery URL, client ID, and client secret sourced from Vault. Add the consuming Deployment to the corresponding `VaultStaticSecret.spec.rolloutRestartTargets`.
- Before rollout, verify the provider's redirect URIs, requested scopes, and property mappings meet the downstream application's requirements. At minimum, OIDC applications commonly require `openid`, `profile`, and `email`; group-gated applications must receive the configured groups claim.
- Test with both an assigned and an unassigned user. For assigned users, ensure the Authentik profile has all claims the application requires (commonly email and a non-empty display name), then confirm successful login and expected downstream role. Confirm an unassigned user is denied at Authentik.

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
5. Add the service to the static `$applications` list in `charts/app-of-apps/{category}/templates/grafana-dashboard.yaml`
6. Ensure the service pods expose a matching `app.kubernetes.io/name` or `app.kubernetes.io/instance` label used by the dashboard selector
7. If adding a new category namespace, also add it to the static `$namespaces` list in `charts/app-of-apps/monitoring/templates/grafana-dashboard-overview.yaml`
8. Add the service to the appropriate category in `charts/apps/utility-services/homepage/templates/services-configmap.yaml`; keep credentials in Vault and reference them through Homepage environment-variable placeholders
9. Add a pod-template checksum for every ConfigMap consumed by the workload
10. Add `rolloutRestartTargets` to every VaultStaticSecret consumed by a workload that requires restart-based secret reloads
11. ArgoCD auto-syncs and deploys (or use `argocd app sync`)

**Manual Helm operations** (avoid unless bootstrapping):
```bash
helm dep update ./charts/apps/{category}/{service}
helm upgrade {service} ./charts/apps/{category}/{service} --install --namespace {namespace} --create-namespace
```

**Debugging deployments:**
- Check ArgoCD UI for sync status and errors
- Verify Vault secret paths match `secrets.path` in values.yaml
- Confirm PV/PVC creation: `kubectl get pv,pvc -n {namespace}`
- For ConfigMap changes, verify the workload pod template contains a checksum of every consumed ConfigMap
- For Vault secret changes, verify the `VaultStaticSecret` has the consuming workload in `spec.rolloutRestartTargets`

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
