#!/bin/bash

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME=$ID
        DISTRO_VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_NAME=$DISTRIB_ID
        DISTRO_VERSION=$DISTRIB_RELEASE
    else
        echo "Unsupported OS"
        exit 1
    fi
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

# Detect the distribution
detect_distro

echo "Detected distribution: $DISTRO_NAME $DISTRO_VERSION"

# Function to remove Docker completely
remove_docker() {
    echo "Removing existing Docker installation..."

    # Stop Docker service if running
    systemctl stop docker
    systemctl stop docker.socket

    # Remove Docker packages
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Remove Docker images, containers, volumes, and networks
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    rm -rf /var/run/docker.sock

    # Remove Docker group and user if they exist
    if getent group docker > /dev/null 2>&1; then
        groupdel docker
    fi
    
    # userdel -r dockeruser // commented by me

    # Clean up unused packages
    apt-get autoremove -y
    apt-get clean

    echo "Docker has been removed successfully."
}

# Function to install Docker on Debian-based systems (Ubuntu, Debian)
install_debian() {
    # Update system packages
    echo "Updating system packages..."
    apt update

    # Install required dependencies
    echo "Installing dependencies..."
    apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker GPG key
    echo "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "Adding Docker repository..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index with Docker's repository
    echo "Updating package index..."
    apt update

    # Install Docker
    echo "Installing Docker..."
    apt install -y docker-ce
}

# Function to install Docker on RedHat-based systems (CentOS, Fedora)
install_redhat() {
    # Update system packages
    echo "Updating system packages..."
    yum update -y

    # Install required dependencies
    echo "Installing dependencies..."
    yum install -y yum-utils device-mapper-persistent-data lvm2

    # Add Docker repository
    echo "Adding Docker repository..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Install Docker
    echo "Installing Docker..."
    yum install -y docker-ce
}

# Function to install Docker on systems using DNF (Fedora, newer RHEL)
install_dnf() {
    # Update system packages
    echo "Updating system packages..."
    dnf update -y

    # Install Docker
    echo "Installing Docker..."
    dnf install -y docker-ce
}

# Install Docker based on the detected distribution
if [[ "$DISTRO_NAME" == "ubuntu" || "$DISTRO_NAME" == "debian" ]]; then
    # Check if Docker is already installed and remove it
    if command -v docker &>/dev/null; then
        remove_docker
    fi
    install_debian
elif [[ "$DISTRO_NAME" == "centos" || "$DISTRO_NAME" == "rhel" || "$DISTRO_NAME" == "fedora" ]]; then
    # Check if Docker is already installed and remove it
    if command -v docker &>/dev/null; then
        remove_docker
    fi
    if command -v dnf &>/dev/null; then
        install_dnf
    else
        install_redhat
    fi
else
    echo "Unsupported distribution: $DISTRO_NAME"
    exit 1
fi

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version

# Output success message
echo "Docker installation is complete."
