# Homeserver Deployment
This repository contains helm charts organized using the `App of Apps` strategy.

## TODO
- [x] rename `stack-apps` folder to `app-of-apps`
- [x] rename `services` folder to `apps`
- [x] solve certificate issue for kubernetes api so that upgrade argocd action can work
- [x] helm linting for argo-cd chart
- [x] find a way to replace the hostPath from vault pv.yaml
- [x] expose kubernetes api some other way to bypass cloudflare challenge in action
- [ ] add refresh for vault secrets
- [ ] install stacker configmaps/secret watcher to restart pods when those change
- [ ] add prometheus/loki and grafana monitoring
- [ ] better backup strategy?
- [ ] better deployment strategy?
- [ ] better documentation
- [ ] use ansible to faster deploy all requirements on a machine?
- [ ] use tokens from the TokenRequest API or manually created secret-based tokens instead of auto-generated secret-based tokens.