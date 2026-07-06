# pgAdmin

## Authentik OIDC

Create a confidential OAuth2/OIDC provider and application in Authentik with slug `pgadmin`.

- Redirect URI: `https://pgadmin.<home-domain>/oauth2/authorize`
- Scope mappings: `openid`, `profile`, and `email`
- Issuer mode: per-provider

Store these values at `kv/core-services/pgadmin`:

```shell
vault kv put kv/core-services/pgadmin \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>' \
  defaultEmail='<local-recovery-email>' \
  defaultPassword='<strong-local-recovery-password>'
```

The chart enables pgAdmin server mode and automatic OIDC user creation. Internal login remains
enabled. On an existing pgAdmin data volume, `defaultEmail` and `defaultPassword` do not replace
an existing account; confirm an internal recovery account before relying on it.
