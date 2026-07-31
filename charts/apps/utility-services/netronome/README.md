# netronome

## Authentik OIDC

Create a confidential OAuth2/OIDC provider and application in Authentik with slug `netronome`.

- Redirect URI: `https://netronome.<home-domain>/api/auth/oidc/callback`
- Signing key: an RSA signing certificate
- Scope mappings: `openid`, `profile`, and `email`
- Issuer mode: per-provider

Store these values at `kv/utility-services/netronome`:

```shell
vault kv put kv/utility-services/netronome \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>' \
  localDomain='<home-domain>'
```
