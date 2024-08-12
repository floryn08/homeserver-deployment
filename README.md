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
   
