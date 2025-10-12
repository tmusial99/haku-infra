## Install
```
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f bootstrap/install-argo.yaml

kubectl apply -n argocd -f bootstrap/app-root.yaml
```