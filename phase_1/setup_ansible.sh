#!/usr/bin/env bash
set -euo pipefail

MASTER_IP="${1:-}"
MANAGED_IP="${2:-}"
ANSIBLE_USER="ubuntu"
ANSIBLE_HOME="/home/${ANSIBLE_USER}"
ANSIBLE_DIR="${ANSIBLE_HOME}/ansible"
PRIVATE_KEY="${ANSIBLE_HOME}/.ssh/id_rsa"

if [ -z "${MASTER_IP}" ] || [ -z "${MANAGED_IP}" ]; then
  echo "Usage: $0 <master_ip> <managed_ip>" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo ">>> Waiting for cloud-init to finish..."
cloud-init status --wait >/dev/null 2>&1 || true

echo ">>> Installing Ansible and Docker SDK..."
sudo apt-get update -y
sudo apt-get install -y ansible python3-docker

echo ">>> Installing community.docker collection..."
ansible-galaxy collection install community.docker --force >/dev/null

echo ">>> Preparing SSH key for master -> managed..."
mkdir -p "${ANSIBLE_HOME}/.ssh"
chmod 700 "${ANSIBLE_HOME}/.ssh"
[ -f "${PRIVATE_KEY}" ] && chmod 600 "${PRIVATE_KEY}"

echo ">>> Writing Ansible configuration..."
mkdir -p "${ANSIBLE_DIR}"

cat > "${ANSIBLE_DIR}/ansible.cfg" <<EOF
[defaults]
inventory = ${ANSIBLE_DIR}/hosts
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent

[ssh_connection]
pipelining = True
EOF

cat > "${ANSIBLE_DIR}/hosts" <<EOF
[master]
master ansible_host=${MASTER_IP} ansible_connection=local

[managed]
managed ansible_host=${MANAGED_IP} ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=${PRIVATE_KEY}

[managed:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

cat > "${ANSIBLE_DIR}/playbook.yml" <<'EOF'
---
- name: Configure managed node and deploy nginx
  hosts: managed
  become: true
  gather_facts: true

  tasks:
    - name: Install Docker and Python Docker SDK
      apt:
        name:
          - docker.io
          - python3-docker
        state: present
        update_cache: true

    - name: Ensure Docker service is enabled and running
      service:
        name: docker
        state: started
        enabled: true

    - name: Add ubuntu user to docker group
      user:
        name: ubuntu
        groups: docker
        append: true

    - name: Deploy nginx container
      community.docker.docker_container:
        name: nginx
        image: nginx:latest
        state: started
        restart_policy: always
        published_ports:
          - "80:80"
EOF

chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${ANSIBLE_DIR}"

echo ">>> Done. Run: cd ${ANSIBLE_DIR} && ansible-playbook playbook.yml"
