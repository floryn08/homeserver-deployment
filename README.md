# Homeserver Deployment
The charts folder contains helm charts organized using the `App of Apps` strategy for my homeserver deployment.

The compose folder contains a docker compose file with essential services deployed on a separate mini pc to improve stability. 

## Installation

This repo is meant to converge through Argo CD using the app-of-apps layout:

- `charts/master-app` creates the top-level service-group Argo CD Applications.
- `charts/app-of-apps/*` creates one Argo CD Application per app in that group.
- `charts/apps/*` contains the actual app charts.

A few core services need to be bootstrapped manually before Argo CD can manage the rest of the repo.

### Prerequisites

Install these locally before bootstrapping:

- `kubectl` pointed at the target cluster
- `helm`
- access to this Git repository from the cluster
- host paths used by the charts created on the nodes that will run those workloads
- Vault secrets populated for domains, app credentials, and `common/backblaze` before enabling apps that depend on them

The default Git source is configured in `charts/master-app/values.yaml` and `charts/app-of-apps/*/values.yaml`:

```yaml
repoUrl: https://github.com/floryn08/homeserver-deployment
targetRevision: HEAD
argocdNamespace: core-services
```

Update those values first if deploying from a fork or a non-`HEAD` revision.

### Bootstrap Core Services

Install Vault first. It stores the secrets consumed by the Vault Secrets Operator and the application charts.

```sh
helm dependency update ./charts/apps/core-services/vault
helm upgrade vault ./charts/apps/core-services/vault \
  --install \
  --namespace core-services \
  --create-namespace
```

After Vault starts, initialize/unseal it if needed and populate the required KV paths. At minimum, apps commonly expect domain secrets and backup credentials under `common/backblaze`.

Install the Vault Secrets Operator so `VaultStaticSecret`, `VaultConnection`, and `VaultAuth` resources can sync Kubernetes Secrets from Vault.

```sh
helm dependency update ./charts/apps/core-services/vault-secrets-operator
helm upgrade vault-secrets-operator ./charts/apps/core-services/vault-secrets-operator \
  --install \
  --namespace core-services \
  --create-namespace
```

Install `homelab-alm`. This provides the custom resources used by app charts, including `IngressRequest` and `CertificateRequest`.

```sh
helm dependency update ./charts/apps/core-services/homelab-alm
helm upgrade homelab-alm ./charts/apps/core-services/homelab-alm \
  --install \
  --namespace core-services \
  --create-namespace
```

Install Argo CD. After this, Argo CD can reconcile the master app and the rest of the chart tree.

```sh
helm dependency update ./charts/apps/core-services/argo-cd
helm upgrade argo-cd ./charts/apps/core-services/argo-cd \
  --install \
  --namespace core-services \
  --create-namespace
```

### Hand Off To Argo CD

Apply the master application once Argo CD is running:

```sh
kubectl apply -n core-services -f charts/master-app.yaml
```

The master app creates Applications for:

- core services
- media management
- utility services
- game servers
- home automation
- AI services
- monitoring, when enabled in `charts/master-app/values.yaml`

Watch Argo CD and Kubernetes until the child applications are created and healthy:

```sh
kubectl get applications -n core-services
kubectl get pods -A
```

### Reinstall Or Upgrade A Bootstrapped Chart

For manual changes before Argo CD takes ownership, use the same pattern:

```sh
helm dependency update ./charts/apps/core-services/<chart>
helm upgrade <release> ./charts/apps/core-services/<chart> \
  --install \
  --namespace core-services \
  --create-namespace
```

Once the master app is active, prefer Git changes and let Argo CD reconcile them.

## Backups and Restores

Backup CronJobs are defined per application chart and can be toggled with `backup.enabled` in each chart values file. The current backup jobs write a local restic repository to `/mnt/hdd2/backups/restic/<release-name>` and then mirror that repository to Backblaze B2 at `<bucket>/<release-name>` using rclone. B2 credentials and `RESTIC_PASSWORD` are synced from Vault into the `<release-name>-backup-job` secret.

Pinned backup images are configured per chart:

```yaml
backup:
  enabled: true
  resticImage: restic/restic:0.18.1
  rcloneImage: rclone/rclone:1.74.3
```

Each backup CronJob uses `concurrencyPolicy: Forbid` so a slow or stuck backup does not overlap with the next scheduled run against the same restic repository.

### Common Restore Flow

1. Stop the application that owns the data before restoring files. For Deployments, scale replicas to `0`; for StatefulSets, scale replicas to `0`.
2. Make the restic repository available locally under `/mnt/hdd2/backups/restic/<release-name>`. If the local copy is missing, sync it back from B2 first.
3. Inspect snapshots:

```sh
restic -r /mnt/hdd2/backups/restic/<release-name> snapshots
```

4. Restore the desired snapshot to a temporary restore directory:

```sh
restic -r /mnt/hdd2/backups/restic/<release-name> restore latest --target /tmp/restore-<release-name>
```

5. Copy only the restored data needed for the service back into the service hostPath. Confirm ownership and permissions before starting the workload again.
6. Start the application and verify logs before considering the restore complete.

### Service Details

| Service | Schedule | Chart | Backup source | Restore target / note |
| --- | --- | --- | --- | --- |
| Minecraft | `0 2 * * *` | `charts/apps/game-servers/minecraft` | `/data` from `/srv/appdata/game-servers/<release-name>` | Stop the Minecraft StatefulSet, restore the world/app data back to the same hostPath, then start it again. |
| Vault | `0 4 * * *` | `charts/apps/core-services/vault` | `/data` from `/srv/appdata/core-services/vault/data` | This deployment appears to use the Vault chart standalone file backend. Stop Vault before restoring the data directory. |
| PostgreSQL | `0 3 * * *` | `charts/apps/core-services/postgresql` | `pg_dumpall` output at `/postgres-dumps/postgresql-backup.sql` | Restore by feeding the SQL dump back to PostgreSQL with `psql` as the postgres admin user. |
| Immich | `0 2 * * *` | `charts/apps/media-management/immich` | `/data/backups` and `/data/library/admin` from `/mnt/hdd2/immich/library` | Restore those paths back into the Immich library hostPath. The Immich PostgreSQL database is not included in this backup job. |
| Vaultwarden | `0 2 * * *` | `charts/apps/utility-services/vaultwarden` | `/data` from `/srv/appdata/utility-services/<release-name>` | Stop Vaultwarden, restore `/data`, confirm file ownership, then start it again. |
| Paperless-ngx | `0 2 * * *` | `charts/apps/utility-services/paperless-ngx` | `/data` from `/mnt/hdd12tb/documents/paperless-ngx` | Restore the Paperless data directory back to the same hostPath before starting the app. |

For PostgreSQL restores, extract the SQL dump from the restored snapshot and run it from a pod or machine that can reach the service:

```sh
PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgresql.core-services.svc -U postgres -f postgresql-backup.sql
```

For B2 recovery, configure rclone with the same `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, and `B2_BUCKET` values used by the backup job, then sync the repository back before running restic commands:

```sh
rclone sync "b2remote:${B2_BUCKET}/<release-name>" "/mnt/hdd2/backups/restic/<release-name>" --fast-list
```
