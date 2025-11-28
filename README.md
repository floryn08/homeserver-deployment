# Homeserver Deployment
The charts folder contains helm charts organized using the `App of Apps` strategy for my homeserver deployment.

The compose folder contains a docker compose file with essential services deployed on a separate mini pc to improve stability. 

## Installation

1. install vault 

```
helm dep update ./charts/apps/core-services/vault

helm upgrade vault ./charts/apps/core-services/vault --install --namespace core-services --create-namespace 
```

2. install vault secrets operator
   
```
helm dep update ./charts/apps/core-services/vault-secrets-operator

helm upgrade vault-secrets-operator ./charts/apps/core-services/vault-secrets-operator --install --namespace core-services --create-namespace
```

3. install homelab alm

```
helm dep update ./charts/apps/core-services/homelab-alm

helm upgrade homelab-alm ./charts/apps/core-services/homelab-alm --install --namespace core-services --create-namespace
```

4. install argocd
   
```
helm dep update ./charts/apps/core-services/argo-cd

helm upgrade argo-cd ./charts/apps/core-services/argo-cd --install --namespace core-services --create-namespace
```

5. create argocd Application using the provided `master-app.yaml` as example
   