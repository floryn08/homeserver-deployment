# Immich

This chart deploys Immich through the upstream Immich chart and deploys its
extension-enabled PostgreSQL image directly with local StatefulSet and Service
templates. The database service names remain `immich-postgresql` and
`immich-postgresql-hl` so the application connection settings do not change.

## PostgreSQL migration

The previous Bitnami chart stores the PostgreSQL 16 cluster in the `data/`
directory at the root of `immich-postgres-data-pvc`. The local StatefulSet uses
PostgreSQL 18 at `/var/lib/postgresql/18/docker`, which maps to the separate
`18/docker/` directory on that PVC. The old files remain untouched for rollback.

Before syncing this chart:

1. Stop the Immich server so it cannot write to PostgreSQL.
2. Drop the empty legacy `vectors` schema left by the completed VectorChord migration.
3. Create and verify a final logical dump of the `immich` database.
4. Sync this chart and wait for `immich-postgresql-0` to become ready.
5. Restore the PostgreSQL 16 dump into the new empty PostgreSQL 18 database.
6. Start Immich and verify database migrations, search, and facial recognition.
7. Keep the old `data/` directory until the migration is fully verified.

The live legacy schema was verified to be empty. Remove it before taking the
final dump:

```sh
kubectl -n media-management exec immich-postgresql-0 -- sh -c \
  'PGPASSWORD="$(cat /opt/bitnami/postgresql/secrets/postgres-user-password)" \
  psql -U immich -d immich -c "DROP SCHEMA IF EXISTS vectors;"'
```

Create the PostgreSQL 16 dump after stopping Immich:

```sh
kubectl -n media-management exec immich-postgresql-0 -- sh -c \
  'PGPASSWORD="$(cat /opt/bitnami/postgresql/secrets/postgres-user-password)" \
  pg_dump -U immich -d immich --clean --if-exists' > immich-postgresql.sql
```

Restore it after the PostgreSQL 18 pod is ready:

```sh
kubectl -n media-management exec -i immich-postgresql-0 -- \
  psql -U immich -d immich < immich-postgresql.sql
```

The PostgreSQL image is `ghcr.io/immich-app/postgres` with PostgreSQL 18,
VectorChord 0.5.3, and pgvector 0.8.1. It intentionally does not include the
retired pgvecto.rs extension. The existing Immich backup CronJob backs up
library paths only; it does not include this database.
