# autobrr

## Authentik OIDC

Create a confidential OAuth2/OIDC provider and application in Authentik with slug `autobrr`.

- Redirect URI: `https://autobrr.<home-domain>/api/auth/oidc/callback`
- Signing key: an RSA signing certificate
- Scope mappings: `openid`, `profile`, and `email`
- Issuer mode: per-provider

Store these values at `kv/media-management/autobrr`:

```shell
vault kv put kv/media-management/autobrr \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>' \
  localDomain='<home-domain>'
```

Built-in login remains enabled as a recovery path.
