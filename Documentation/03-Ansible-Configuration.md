# 03. Configuration Management with Ansible

## 1. Role in the DevOps Lifecycle
While **Terraform** provisions the underlying virtual machines and cloud resources (orchestration), **Ansible** is responsible for automating software installation, dependency management, and configuration enforcement across Jenkins controllers and worker agents.

This guarantees that build environments are 100% reproducible, eliminating the *"works on my machine"* problem.

---

## 2. Directory Structure
```
ansible/
├── ansible.cfg                          # Global Ansible defaults (sudo escalation, host key bypass)
├── inventory/
│   └── hosts.ini                        # Target hosts (local controller, remote agents)
└── playbooks/
    ├── setup_tools.yml                  # Automated installation of Docker, AWS CLI, kubectl, Helm, Terraform
    └── configure_jenkins_agent.yml      # User permissions, socket configuration, workspace prep
```

---

## 3. Playbook Breakdown

### 1. `setup_tools.yml` (Tooling Automation)
Automates the end-to-end installation of all required DevOps tooling on Ubuntu/Debian hosts:
1.  **Docker Engine & CLI:** Installs official Docker CE, enables the daemon, and registers systemd service.
2.  **AWS CLI v2:** Downloads and executes the official AWS CLI v2 binary bundle.
3.  **Kubectl (v1.29):** Installs the latest stable Kubernetes client binary with executable permissions in `/usr/local/bin/`.
4.  **Helm 3:** Installs the Helm package manager via the official automated script.
5.  **HashiCorp Terraform:** Adds the HashiCorp APT repository and installs the Terraform CLI.
6.  **Verification:** Runs verification commands to assert all tools are functioning and logs versions.

### 2. `configure_jenkins_agent.yml` (Agent Provisioning)
1.  Creates the `jenkins` system user and group.
2.  Adds `jenkins` and `ubuntu` users to the `docker` security group, enabling non-root container building.
3.  Configures read/write permissions on `/var/run/docker.sock`.
4.  Initializes the `/var/jenkins_home/workspace` and `/var/jenkins_home/.kube` credential directories.

---

## 4. Execution Guide

### Local Execution (Jenkins Server / Local Runner)
```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/setup_tools.yml --connection=local
ansible-playbook -i inventory/hosts.ini playbooks/configure_jenkins_agent.yml --connection=local
```

### Remote Execution (Target EC2 Agent)
```bash
# Update inventory/hosts.ini with the target EC2 public IP and private key
ansible-playbook -i inventory/hosts.ini playbooks/setup_tools.yml
```
