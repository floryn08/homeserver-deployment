# Grafana

## Authentik OIDC

Create the Grafana application and OAuth2/OIDC provider in Authentik before syncing this chart.

1. In **Applications > Applications**, select **New Provider**.
2. Create an application named `Grafana` with slug `grafana` and launch URL
   `https://grafana.<home-domain>`.
3. Select the **OAuth2/OIDC** provider type and configure:
   - Client type: `Confidential`
   - Redirect URI: `https://grafana.<home-domain>/login/generic_oauth`
   - Signing key: an Authentik signing certificate
   - Scope mappings: `openid`, `profile`, `email`, and `offline_access`
   - Issuer mode: per-provider (the default)
4. Ensure users allowed to open the application have an email address. Optionally create
   the `Grafana Admins` and `Grafana Editors` groups. Members receive the corresponding
   Grafana organization role; all other permitted users receive `Viewer`.
5. Store the provider credentials and domains in Vault:

   ```shell
   vault kv put kv/monitoring/grafana \
     adminUser='admin' \
     adminPassword='<stable-strong-password>' \
     authentikClientId='<client-id>' \
     authentikClientSecret='<client-secret>' \
     authentikDomain='<primary-domain-without-auth-prefix>' \
     localDomain='<home-domain>'
   ```

For an existing Grafana database, the environment variable does not replace the stored
admin password. After the first sync with `adminPassword` populated, reset it once using
the value already injected into the container:

```shell
kubectl -n monitoring exec deploy/grafana -c grafana -- sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
```

After Argo CD syncs the chart, the Grafana login page displays **Sign in with Authentik**.
The existing Grafana login form remains enabled as a recovery path.
