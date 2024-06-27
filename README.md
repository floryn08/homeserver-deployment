# Homeserver Deployment
This repository contains helm charts organized using the `App of Apps` strategy.

## Installation

1. install vault 

```
helm dep update ./charts/apps/core-services/vault

helm upgrade vault ./charts/apps/core-services/vault --install --namespace core-services --create-namespace --set vaultDataPath="CHANGE_ME"
```

2. install vault secrets operator
   
```
helm dep update ./charts/apps/core-services/vault-secrets-operator

helm upgrade vault-secrets-operator ./charts/apps/core-services/vault-secrets-operator --install --namespace core-services --create-namespace
```

3. install argocd
   
```
helm dep update ./charts/apps/core-services/argo-cd

helm upgrade argo-cd ./charts/apps/core-services/argo-cd --install --namespace core-services --create-namespace
```

4. create argocd Application using the provided `master-app.yaml` as example 

## TODO
- [x] rename `stack-apps` folder to `app-of-apps`
- [x] rename `services` folder to `apps`
- [x] solve certificate issue for kubernetes api so that upgrade argocd action can work
- [x] helm linting for argo-cd chart
- [x] find a way to replace the hostPath from vault pv.yaml
- [x] expose kubernetes api some other way to bypass cloudflare challenge in action
- [x] manage dependencies between argo-cd and vault
- [x] add refresh for vault secrets
- [x] install stacker configmaps/secret watcher to restart pods when those change
- [x] better documentation
- [ ] add prometheus/loki and grafana monitoring
- [ ] use ansible to faster deploy all requirements on a machine?
- [ ] use tokens from the TokenRequest API or manually created secret-based tokens instead of auto-generated secret-based tokens.
- [ ] better backup strategy?
- [ ] better deployment strategy?