## Prepare the host
```
# In "/etc/default/grub"

GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_guc=3"

# Then `update-grub && reboot`

# In "/etc/modules"

overlay
br_netfilter

# Then `modprobe overlay && modprobe br_netfilter`
```

## Prepare LXC
```
# In "/etc/pve/lxc/xxx.conf

lxc.cgroup2.devices.allow: c 226:1 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/card1 dev/dri/card1 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file

lxc.mount.auto: proc:rw sys:rw
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file
```

## Uninstall k3s
```
sudo k3s-uninstall.sh
```

## Install k3s
```
# Install k3s (without Traefik)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --kubelet-arg=fail-swap-on=false" sh -

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy kubeconfig and fix permissions
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config

# Export KUBECONFIG variable permanently
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Test
kubectl get nodes
```

## Prepare the node
```
# Import sealed-secrets-key
kubectl apply -f sealed-secrets-key.yaml

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
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