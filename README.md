# Homeserver Deployment
This repository contains helm charts organized using the `App of Apps` strategy.

## TODO
- [ ] add refresh for vault secrets
- [ ] install stacker configmaps/secret watcher to restart pods when those change
- [ ] rename `stack-apps` folder to `app-of-apps`
- [ ] rename `services` folder to `apps`
- [ ] solve certificate issue for kubernetes api so that upgrade argocd action can work
- [ ] find a way to use `sed` to replace the hostPath from vault pv.yaml
- [ ] add prometheus/loki and grafana monitoring
- [ ] better backup strategy?
- [ ] use ansible to faster deploy all requirements on a machine?