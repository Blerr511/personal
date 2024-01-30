#!/bin/bash

set -e

# Function to log messages
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RESET='\033[0m' # Reset text color

# Function to log messages with colors
log_message() {
  local log_message="$1"
  local log_type="$2" # success, warning, error

  case "$log_type" in
  "success")
    log_color="$COLOR_GREEN"
    ;;
  "warning")
    log_color="$COLOR_YELLOW"
    ;;
  "error")
    log_color="$COLOR_RED"
    ;;
  *)
    log_color=""
    ;;
  esac

  echo -e "$(date +'%Y-%m-%d %H:%M:%S') - ${log_color}${log_message}${COLOR_RESET}"
}

installing() {
  local pack="$1"
  log_message "Installing '${pack}'" "warning"
}

already_installed() {
  local pack="$1"
  log_message "Package '${pack}' already installed" "success"
}

success_installed() {
  local pack="$1"
  log_message "Package '${pack}' installed" "success"
}

# Function to check if a package is installed
is_package_installed() {
  local package_name="$1"
  if dpkg -l | grep -q "^ii  $package_name "; then
    return 0
  else
    return 1
  fi
}

# Update the package repository
log_message "Updating package repository" "warning"
apt update

# Install required packages
required_packages=("apt-transport-https" "gnupg" "sudo" "ca-certificates" "curl")
for package in "${required_packages[@]}"; do
  if ! is_package_installed "$package"; then
    installing "$package"
    apt-get install -y "$package"
    success_installed "$package"
  else
    already_installed "$package"
  fi
done

# Install Slack via Snap
if ! snap list | grep -q "slack"; then
  installing "Slack via Snap"
  snap install slack --classic
else
  already_installed "Slack"
fi

# Install JQ
if ! is_package_installed "jq"; then
  installing "jq"
  apt install jq -y
else
  already_installed "jq"
fi

# Install Zsh
if ! is_package_installed "zsh"; then
  installing "Zsh"
  apt install zsh -y
else
  already_installed "Zsh"
fi

if [ "$(getent passwd $USER | cut -d: -f7)" != "$(which zsh)" ]; then
  log_message "Setting Zsh as the default shell (chsh)" "warning"
  chsh -s "$(which zsh)" "$USER"
else
  log_message "Zsh is already the default shell" "success"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  installing "Oh My Zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  already_installed "Oh My Zsh is already installed"
fi

# Set Oh My Zsh theme
log_message "Setting Oh My Zsh theme to bira" "success"

# omz theme set bira

# Install Guake
if ! is_package_installed "guake"; then
  installing "Installing Guake"
  apt install guake -y
  success_installed "Guake"
else
  already_installed "Guake"
fi

# Install Docker
if ! is_package_installed "docker-ce"; then
  installing "Docker"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  success_installed "Docker"

  installing "docker-compose"
  curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  docker-compose --version
  success_installed "docker-compose"
  log_message "Running docker postinstall steps" "warning"

  groupadd docker
  usermod -aG docker "$USER"
  newgrp docker

else
  already_installed "Docker"
fi

# Install Git
if ! is_package_installed "git"; then
  installing "Git"
  apt install -y git
  success_installed "Git"
else
  already_installed "Git"
fi

if ! is_package_installed "go"; then

  installing "go"

  apt install -y golang-go

  success_installed "go"

else
  already_installed "go"
fi

# Install Node.js and npm
if ! is_package_installed "nodejs"; then
  installing "Node.js and npm"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  NODE_MAJOR=20
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install nodejs -y
  success_installed "Node.js and npm"

  # make cache folder (if missing) and take ownership
  mkdir -p /usr/local/n
  chown -R $(whoami) /usr/local/n
  # make sure the required folders exist (safe to execute even if they already exist)
  mkdir -p /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share
  # take ownership of Node.js install destination folders
  chown -R $(whoami) /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share
else
  already_installed "Node.js and npm"
fi

# Install Node version manager (n)

if ! npm list -g "n" &>/dev/null; then
  installing "npm package: Node version manager (n)"
  npm install -g n
  n install 18
  success_installed "Node version manager (n)"
else
  already_installed "npm packageL n"
fi

global_npm_packages=("yarn" "pnpm" "@bazel/bazelisk")

# Check and install global npm packages
for package in "${global_npm_packages[@]}"; do
  if ! npm list -g "$package" &>/dev/null; then
    installing "npm package: $package"
    npm install -g "$package"
  else
    already_installed "npm package $package"
  fi
done

# Install Terraform
if ! is_package_installed "terraform"; then
  installing "Terraform"
  installing "HashiCorp GPG key"
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  apt-get update
  apt-get install -y terraform
  success_installed "Terraform"
else
  already_installed "Terraform"
fi

# Install Kubernetes
if ! is_package_installed "kubectl"; then
  installing "Kubernetes"
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  apt-get update
  apt-get install -y kubectl
  success_installed "Kubernetes"
else
  already_installed "Kubernetes"
fi

# Install k9s via Snap
if ! snap list | grep -q "k9s"; then
  installing "k9s via Snap"
  snap install k9s --devmode
  success_installed "k9s via Snap"
else
  already_installed "k9s via Snap"
fi

if ! command -v gcloud &>/dev/null; then
  installing "gcloud cli"

  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

  apt-get update

  apt-get install google-cloud-cli

  apt-get install google-cloud-sdk-gke-gcloud-auth-plugin

  success_installed "gcloud cli"

else
  already_installed "gcloud cli"
fi

echo "Note: Please install Chrome and Visual Studio Code manually."
