## Uninstall k3s
```
sudo k3s-uninstall.sh
chmod +x clear-longhorn-devices.sh
sudo ./clear-longhorn-devices.sh [--dry-run]

```

## Install k3s
```
# Install k3s (without Traefik and local-path)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --disable local-storage" sh -


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
helm repo add argo https://argoproj.github.io/argo-helm

helm repo update

helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace

kubectl apply -f app-of-apps.yaml
```


## Get admin password
```
username: admin
password:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```