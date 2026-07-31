# profilarr

## Authentik OIDC

Create a confidential OAuth2/OIDC provider and application in Authentik with slug `profilarr`.

- Redirect URI: `https://profilarr.<home-domain>/auth/oidc/callback`
- Signing key: an RSA signing certificate
- Scope mappings: `openid`, `profile`, and `email`
- Issuer mode: per-provider

Store these values at `kv/media-management/profilarr`:

```shell
vault kv put kv/media-management/profilarr \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>'
```
