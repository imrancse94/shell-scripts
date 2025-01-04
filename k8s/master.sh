KUBERNETES_VERSION="v1.32"
MASTER_PRIVATE_IP="10.0.3.10"

sudo apt update && sudo apt upgrade -y

sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sysctl net.ipv4.ip_forward

sudo apt install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Install CNI Plugin
wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz

# Configure IPv4 and IPTables
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
modprobe br_netfilter
sysctl -p /etc/sysctl.conf



# For kubectl, kubeadm, kubelet install
sudo apt-get update

# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y gpg

# Download the Release key
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

sudo kubeadm reset -f
sudo rm -rf $HOME/.kube
sudo kubeadm config images pull
sudo kubeadm init --apiserver-advertise-address $MASTER_PRIVATE_IP --control-plane-endpoint $MASTER_PRIVATE_IP --ignore-preflight-errors Swap

export KUBECONFIG=/etc/kubernetes/admin.conf

sudo apt install -y bash-completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc