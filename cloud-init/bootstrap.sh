#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
exec > >(tee -a /var/log/asobi-bootstrap.log) 2>&1

node_version=v24.20.0
codex_version=0.153.4
workdir=$(mktemp -d /tmp/asobi-bootstrap.XXXXXX)
cd "$workdir"

# Install the official Docker packages, including the Compose plugin.
install -m 0755 -d /etc/apt/keyrings
curl --fail --show-error --silent --location --retry 5 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable' > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# Install a pinned Node LTS build after validating its published checksum.
node_archive="node-${node_version}-linux-x64.tar.xz"
curl --fail --show-error --silent --location --retry 5 "https://nodejs.org/dist/${node_version}/${node_archive}" -o "$node_archive"
curl --fail --show-error --silent --location --retry 5 "https://nodejs.org/dist/${node_version}/SHASUMS256.txt" -o SHASUMS256.txt
awk -v archive="$node_archive" '$2 == archive' SHASUMS256.txt > node.sha256
test -s node.sha256
sha256sum --check node.sha256
tar -xJf "$node_archive" -C /usr/local --strip-components=1
npm install --global "@openai/codex@${codex_version}"

# uv is isolated from the OS Python installation.
python3 -m venv /opt/asobi-uv
/opt/asobi-uv/bin/pip install --disable-pip-version-check uv
ln -sfn /opt/asobi-uv/bin/uv /usr/local/bin/uv
ln -sfn /opt/asobi-uv/bin/uvx /usr/local/bin/uvx

curl --fail --show-error --silent --location --retry 5 https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install --update

# Canonical's Ubuntu AMI supplies the SSM Agent as a snap.
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl enable --now ssh
install -d -o ubuntu -g ubuntu -m 0755 /home/ubuntu/projects
install -d -o ubuntu -g ubuntu -m 0700 /home/ubuntu/.codex

{
  date --iso-8601=seconds
  uname -a
  node --version
  npm --version
  codex --version
  python3 --version
  uv --version
  git --version
  gh --version
  docker --version
  docker compose version
  aws --version
  tmux -V
  dpkg-query -W git gh tmux python3 docker-ce docker-compose-plugin
} > /var/log/asobi-tool-versions.txt
chmod 0644 /var/log/asobi-tool-versions.txt
touch /var/lib/asobi-bootstrap-complete
printf '%s\n' 'ASOBI bootstrap complete.'
