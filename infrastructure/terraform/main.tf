# Générer automatiquement la clé SSH
resource "tls_private_key" "furious_ducks_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde de la clé privée
resource "local_file" "private_key" {
  content         = tls_private_key.furious_ducks_key.private_key_pem
  filename        = pathexpand("~/.ssh/mykey.pem")
  file_permission = "0600"
}

# Importer la clé publique dans AWS
resource "aws_key_pair" "furious_ducks_keypair" {
  key_name   = "furious-ducks-key"
  public_key = tls_private_key.furious_ducks_key.public_key_openssh
}

# Security Group avec tous les ports nécessaires
resource "aws_security_group" "common_sg" {
  name        = "${var.project_name}-common-sg"
  description = "Allow SSH, HTTP, HTTPS, Docker Swarm and app ports"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : aws_vpc.furious_vpc[0].id

  # Ports standards
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ports applicatifs
  dynamic "ingress" {
    for_each = [4200, 5000, 8000, 43000, 27017, 4000, 3000, 4001, 27018, 3001, 9090, 8080]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Docker Swarm
  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Script d'installation Docker
data "template_file" "install_docker" {
  template = <<EOF
#!/bin/bash
apt-get update -y
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker
EOF
}

locals {
  instances = {
    ci_cd = "CI/CD"
    dev   = "Development"
    qa    = "QA"
    prod  = "Production"
  }
}

# Création des instances EC2
resource "aws_instance" "servers" {
  for_each               = local.instances
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.furious_ducks_keypair.key_name
  subnet_id              = var.subnet_id != "" ? var.subnet_id : aws_subnet.furious_subnet[0].id
  vpc_security_group_ids = [aws_security_group.common_sg.id]
  user_data              = data.template_file.install_docker.rendered

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Project     = var.project_name
    Environment = each.value
  }
}

# Génération automatique du fichier inventory.ini pour Ansible
resource "local_file" "ansible_inventory" {
  content = <<EOT
[ci_cd_server]
${aws_instance.servers["ci_cd"].public_ip}

[dev_server]
${aws_instance.servers["dev"].public_ip}

[qa_server]
${aws_instance.servers["qa"].public_ip}

[prod_server]
${aws_instance.servers["prod"].public_ip}

[all:vars]
ansible_user=admin
ansible_ssh_private_key_file=~/.ssh/mykey.pem
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}