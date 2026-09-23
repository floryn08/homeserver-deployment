# Hermes Agent

Hermes is available at `https://hermes.home`.

Before deploying, manually create an Authentik application with slug `hermes` and a public OAuth2/OIDC provider using authorization-code flow with PKCE (S256). Its permitted redirect URI must be:

```text
https://hermes.home/auth/callback
```

Assign permitted users to the `app-hermes-users` Authentik group.

Populate `kv/data/ai-services/hermes` in Vault with:

```text
HERMES_DASHBOARD_OIDC_ISSUER=https://auth.<your-domain>/application/o/hermes/
HERMES_DASHBOARD_OIDC_CLIENT_ID=<Authentik public OIDC client ID>
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=<fallback username>
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=<scrypt password hash>
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<32+ byte random signing secret>
```

Generate the basic-auth password hash with:

```sh
docker run --rm nousresearch/hermes-agent:v2026.9.21 python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('your-password'))"
```

Hermes only supports public PKCE OIDC clients, so no OIDC client secret is required. After the first deployment, configure the model provider from the Hermes dashboard; all agent state is persisted at `/srv/appdata/ai-services/hermes`.
