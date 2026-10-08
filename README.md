# AWS + Terraform + Ansible Lab

A Terraform configuration that provisions a small AWS lab (VPC, two EC2 instances)
and, at apply time, auto-bootstraps an Ansible controller on the first instance so
you can deploy a Dockerized nginx on the second with a single command.

## Topology

```
Internet
   |
 [VPC 172.26.0.0/16]
   |-- Internet Gateway
   |-- Subnet 172.26.1.0/24 (public) ---- Security Group (SSH/22 + HTTP/80)
   |-- EC2 "project1-ec2"  (master / Ansible controller + managed target)
   `-- EC2 "project2-ec2"  (managed node / Docker + nginx)
```

## Files

| File                  | Purpose                                                       |
| --------------------- | ------------------------------------------------------------- |
| `main.tf`             | VPC, network, security group, key pair, EC2, Ansible bootstrap |
| `variables.tf`        | Input variables                                               |
| `terraform.tfvars`    | Default variable values                                       |
| `outputs.tf`          | Public/private IP outputs                                     |
| `setup_ansible.sh`    | Bootstrap script run on the master during `terraform apply`   |

## Prerequisites

- Terraform >= 1.3
- AWS credentials configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` / `~/.aws/credentials`)
- An SSH key pair: `~/.ssh/id_rsa` + `~/.ssh/id_rsa.pub`

## Usage

```bash
# 1. (Optional) adjust variables
#    edit terraform.tfvars (region, CIDRs, instance_type, ssh_cidr)

# 2. Init once
terraform init

# 3. Provision + bootstrap Ansible on the master
terraform apply

# 4. Get the master's public IP
terraform output -raw master_public_ip

# 5. SSH into the master and deploy
ssh ubuntu@<master_public_ip>
cd ~/ansible && ansible-playbook playbook.yml
```

## What happens on apply

`null_resource.ansible_setup` connects to the master over SSH and runs
`setup_ansible.sh`, which:

1. Waits for cloud-init to finish.
2. Installs `ansible` and the `community.docker` collection.
3. Copies the lab private key to `/home/ubuntu/.ssh/id_rsa` (master -> managed).
4. Writes `~/ansible/ansible.cfg`, `~/ansible/hosts`, and `~/ansible/playbook.yml`.

## The playbook

`playbook.yml` (on the master) targets the `managed` host and:

- Installs `docker.io` and the Python Docker SDK.
- Enables and starts the Docker service.
- Adds `ubuntu` to the `docker` group.
- Deploys an `nginx` container, published on port 80.

Verify the deployment:

```bash
curl http://$(terraform output -raw managed_public_ip)
```

## Outputs

| Output               | Value                          |
| -------------------- | ------------------------------ |
| `vpc_id`             | Id of the created VPC          |
| `public_subnet_id`   | Id of the public subnet        |
| `master_public_ip`   | Public IP of the Ansible master|
| `managed_public_ip`  | Public IP of the managed node  |

## Notes

- Security group allows SSH and HTTP from `ssh_cidr` (default `0.0.0.0/0`).
  Restrict this before using outside a lab.
- The bootstrap re-runs only when instance IPs change. Force a re-run with:
  `terraform apply -replace=null_resource.ansible_setup`