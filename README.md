## Uninstall k3s
```
sudo k3s-uninstall.sh
```

## Install k3s
```
# Install k3s (without Traefik)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy kubeconfig and fix permissions
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Export KUBECONFIG variable permanently
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Test
kubectl get nodes
```

## Install argoCD
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