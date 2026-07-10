# CrowdSec

## CrowdSec Web UI

Create a confidential OAuth2/OIDC provider and application in Authentik with slug
`crowdsec-web-ui`.

- Redirect URI: `https://crowdsec.<home-domain>/api/auth/oidc/callback`
- Scope mappings: `openid`, `profile`, `email`, and `groups`
- Issuer mode: per-provider

Create the Authentik groups `crowdsec-admins` and `crowdsec-viewers`, then assign
them to the provider's users. Members of the first group can manage CrowdSec;
members of the second group have read-only access. Users outside both groups are
denied.

Store these values at `kv/core-services/crowdsec` in addition to the existing
CrowdSec keys:

```shell
vault kv patch kv/core-services/crowdsec \
  authentikClientId='<client-id>' \
  authentikClientSecret='<client-secret>' \
  authentikDomain='<primary-domain-without-auth-prefix>'
```

The Web UI also authenticates to the CrowdSec Local API as the `crowdsec-web-ui`
machine. Register it once after the secret syncs:

```shell
kubectl -n core-services exec deploy/crowdsec-lapi -- \
  sh -c 'cscli machines add crowdsec-web-ui --password "$CROWDSEC_WEB_UI_PASSWORD" -f /dev/null'
```
