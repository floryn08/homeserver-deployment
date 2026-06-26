# Vault PKI flow for homelab certificates

This chart uses cert-manager with a Vault-backed `ClusterIssuer` named
`ca-issuer`. Vault owns the CA private keys and signs route certificates through
the intermediate PKI engine.

## Target design

The trust chain is:

```text
Homelab Root CA        stored in Vault pki/
  -> Intermediate CA   stored in Vault pki_int/
    -> Route certs     issued by cert-manager through pki_int/sign/homelab
```

Only the root CA certificate from `pki/` should be imported into OS/browser trust
stores. Do not trust route certificates or the intermediate as the main trust
anchor.

## Vault PKI setup

Create two PKI secrets engines:

```text
pki      root CA, long lived
pki_int  intermediate CA, used for signing leaf certificates
```

Suggested TTLs:

```text
pki max lease TTL:     87600h  # 10 years
pki_int max lease TTL: 43829h  # 5 years
```

Create the root CA in `pki/`:

```text
Type: internal root
Common name: Homelab Root CA
TTL: 87600h
Key type: rsa
Key bits: 4096
```

Create the intermediate CA in `pki_int/`:

1. Open `pki_int/`.
2. Select `Configure PKI`.
3. Select `Generate intermediate CSR`.
4. Use:

```text
Common name: Homelab Intermediate CA
TTL: 43829h
Key type: rsa
Key bits: 4096
```

Sign the generated CSR from the root `pki/` engine. The signed output contains
multiple fields:

```text
certificate  signed intermediate certificate
issuing_ca   root CA certificate
ca_chain     intermediate plus root chain
```

Import the `certificate` value back into `pki_int/`. In the UI this may appear as
`Import issuer`, `Import signed intermediate`, or similar. With the CLI:

```bash
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
```

The `intermediate.cert.pem` file should contain the signed intermediate
certificate from the root signing output.

## Signing role

Create a Vault PKI role under `pki_int/roles`, for example `homelab`.

Typical settings:

```text
Allowed domains: internal domains served by Traefik
Allow subdomains: enabled
Allow wildcard certificates: enabled only if wildcard certs are needed
Max TTL: 8760h or shorter for route certificates
Server cert usage: enabled
Client cert usage: disabled unless mTLS is needed
```

cert-manager signs certificates through this Vault endpoint:

```text
pki_int/sign/homelab
```

## Vault policy and auth

Create a Vault policy for cert-manager:

```hcl
path "pki_int/sign/homelab" {
  capabilities = ["update"]
}

path "pki_int/ca" {
  capabilities = ["read"]
}
```

Example policy name:

```text
cert-manager-pki
```

Create or update the Vault Kubernetes auth role used by cert-manager:

```bash
vault write auth/kubernetes/role/cert-manager-ca-issuer \
  bound_service_account_names=vault-issuer \
  bound_service_account_namespaces=core-services \
  audience="vault://ca-issuer" \
  policies=cert-manager-pki \
  ttl=1m
```

Adjust `auth/kubernetes` if the Kubernetes auth method is mounted somewhere
else.

## Kubernetes resources in this chart

`templates/service-account.yaml` creates the `vault-issuer` service account and
allows the cert-manager service account to request tokens for it.

`templates/certificate-authority.yaml` creates the `ClusterIssuer`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  vault:
    server: http://vault.core-services.svc:8200
    path: pki_int/sign/homelab
    auth:
      kubernetes:
        role: cert-manager-ca-issuer
        mountPath: /v1/auth/kubernetes
        serviceAccountRef:
          name: vault-issuer
```

The issuer name stays `ca-issuer` so existing certificate request flows do not
need to change.

## Local trust

Download the root CA certificate from `pki/` and import that into the operating
system trust store:

```bash
vault read -field=certificate pki/cert/ca
```

Do not import:

```text
leaf route certificates
pki_int intermediate certificate as the main trust anchor
ca_chain unless the OS trust import explicitly expects a bundle
```

After cert-manager issues route certificates, Traefik should serve:

```text
leaf route certificate
Homelab Intermediate CA
```

Clients trust the route certificate because the chain ends at the locally trusted
`Homelab Root CA`.

## Validation

Check the issuer after Argo applies the chart:

```bash
kubectl describe clusterissuer ca-issuer
```

Then request or renew one route certificate and inspect the served certificate
chain. If clients still report an unknown issuer after trusting the root, verify
that the TLS secret includes the intermediate in `tls.crt`.
