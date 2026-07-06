# qui

## Authentik OIDC

Create a confidential OAuth2/OIDC provider and application in Authentik with slug `qui`.

- Redirect URI: `https://qui.<home-domain>/api/auth/oidc/callback`
- Signing key: an RSA signing certificate
- Scope mappings: `openid`, `profile`, and `email`
- Issuer mode: per-provider

Store these values at `kv/media-management/qui`:

```shell
vault kv put kv/media-management/qui \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>' \
  localDomain='<home-domain>'
```

Built-in login remains enabled as a recovery path. QUI enables PKCE automatically when
Authentik advertises S256 support.
