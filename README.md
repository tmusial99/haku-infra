## Install
```
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f bootstrap/install-argo.yaml

kubectl apply -n argocd -f bootstrap/app-root.yaml

kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "NodePort"}}'

kubectl -n argocd get svc argocd-server
```


## Get admin password
```
username: admin
password:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```