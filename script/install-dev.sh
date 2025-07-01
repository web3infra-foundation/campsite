#!/bin/bash

# ==============================================================================
# One-click Ubuntu Development Environment Setup Script (Simplified Comments)
# Installs:
#   - NVM (Node Version Manager) and latest LTS Node.js
#   - rbenv and Ruby 3.3.4
# Usage:
#   1. Save this script as setup_dev_env.sh
#   2. chmod +x setup_dev_env.sh
#   3. ./setup_dev_env.sh
#   4. Restart your terminal or run source ~/.bashrc
# ==============================================================================

set -e

NODE_VERSION_TO_INSTALL="lts"
RUBY_VERSION_TO_INSTALL="3.3.4"

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

info() { echo -e "${COLOR_BLUE}[INFO] $1${COLOR_NC}"; }
success() { echo -e "${COLOR_GREEN}[SUCCESS] $1${COLOR_NC}"; }
warn() { echo -e "${COLOR_YELLOW}[WARNING] $1${COLOR_NC}"; }

add_to_profile() {
    local profile_file="$HOME/.bashrc"
    local line_to_add="$1"
    if ! grep -qF -- "$line_to_add" "$profile_file"; then
        echo -e "\n$line_to_add" >> "$profile_file"
    fi
}

install_nvm_and_node() {
    info "Installing NVM and Node.js ($NODE_VERSION_TO_INSTALL)"
    sudo apt-get update
    sudo apt-get install -y curl build-essential
    local NVM_VERSION=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    nvm install "$NODE_VERSION_TO_INSTALL"
    nvm alias default "$NODE_VERSION_TO_INSTALL"
    nvm use default

    success "NVM and Node.js installation completed"
    node -v
    npm -v
}

install_rbenv_and_ruby() {
    info "安装 rbenv 和 Ruby ($RUBY_VERSION_TO_INSTALL)"
    sudo apt-get update
    sudo apt-get install -y git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev

    if [ ! -d "$HOME/.rbenv" ]; then
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    fi
    add_to_profile 'export PATH="$HOME/.rbenv/bin:$PATH"'
    add_to_profile 'eval "$(rbenv init -)"'
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"

    if [ ! -d "$(rbenv root)/plugins/ruby-build" ]; then
        git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build"
    fi

    if ! rbenv versions | grep -q "$RUBY_VERSION_TO_INSTALL"; then
        rbenv install "$RUBY_VERSION_TO_INSTALL"
    fi
    rbenv global "$RUBY_VERSION_TO_INSTALL"
    add_to_profile 'gem: --no-document'

    gem install bundler
    rbenv rehash

    success "rbenv and Ruby installation completed"
    ruby -v
    gem -v
    bundler -v
}

main() {
    info "Starting one-click Ubuntu development environment setup"
    install_nvm_and_node
    install_rbenv_and_ruby
    echo
    success "All installations completed!"
    warn "Please restart your terminal or run: source ~/.bashrc"
}

main
