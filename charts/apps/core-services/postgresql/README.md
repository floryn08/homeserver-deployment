# PostgreSQL

This chart deploys the official PostgreSQL image directly with a StatefulSet.
It intentionally keeps the existing `postgresql` and `postgresql-hl` service
names so current consumers do not need connection changes.

## Bitnami migration

The old Bitnami database uses `/bitnami/postgresql/data`, which is the `data/`
directory at the root of `postgresql-pvc`. PostgreSQL 18 uses
`/var/lib/postgresql/18/docker`; the new StatefulSet mounts the same PVC at
`/var/lib/postgresql` and initializes the separate `18/docker/` directory.
The old files are therefore retained for rollback and must not be copied into
the new directory.

Before syncing this chart:

1. Stop or scale down every application that writes to the shared database.
2. Create and verify a final `pg_dumpall` from the Bitnami pod.
3. Sync this chart and wait for `postgresql-0` to become ready.
4. Restore the dump into the new empty PostgreSQL instance.
5. Restart consumers and validate each database-backed application.
6. Keep the old `data/` directory until the migration is fully verified.

The chart does not perform the restore automatically. This keeps destructive
database operations outside Argo CD reconciliation.
