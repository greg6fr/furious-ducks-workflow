# Générer automatiquement la clé SSH
resource "tls_private_key" "furious_ducks_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde de la clé privée dans le répertoire ansible/keys
resource "local_file" "private_key" {
  content         = tls_private_key.furious_ducks_key.private_key_pem
  filename        = "../ansible/keys/mykey.pem"
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
  for_each = local.instances
  ami      = var.ami_id
  # Use t3.large for CI/CD, t3.medium for prod, t3.small for qa, t3.micro for dev
  instance_type          = each.key == "ci_cd" ? "t3.large" : (each.key == "prod" ? "t3.medium" : (each.key == "qa" ? "t3.small" : (each.key == "dev" ? "t3.micro" : var.instance_type)))
  key_name               = aws_key_pair.furious_ducks_keypair.key_name
  subnet_id              = var.subnet_id != "" ? var.subnet_id : aws_subnet.furious_subnet[0].id
  vpc_security_group_ids = [aws_security_group.common_sg.id]
  user_data              = data.template_file.install_docker.rendered

  # Configuration du volume de stockage - 50Go pour CI/CD, 8Go par défaut pour les autres
  root_block_device {
    volume_type = "gp3"
    volume_size = each.key == "ci_cd" ? 50 : 8
    encrypted   = true
    delete_on_termination = true
    
    tags = {
      Name = "${var.project_name}-${each.key}-root-volume"
    }
  }

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Project     = var.project_name
    Environment = each.value
  }
}

# Création des Elastic IP pour tous les serveurs
resource "aws_eip" "server_eips" {
  for_each = local.instances
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-${each.key}-eip"
    Project     = var.project_name
    Environment = each.value
  }
}

# Association des Elastic IP aux instances
resource "aws_eip_association" "server_eip_associations" {
  for_each      = local.instances
  instance_id   = aws_instance.servers[each.key].id
  allocation_id = aws_eip.server_eips[each.key].id
}

# Génération automatique du fichier inventory.ini pour Ansible
resource "local_file" "ansible_inventory" {
  content  = <<EOT
[ci_cd_server]
${aws_eip.server_eips["ci_cd"].public_ip}

[dev_server]
${aws_eip.server_eips["dev"].public_ip}

[qa_server]
${aws_eip.server_eips["qa"].public_ip}

[prod_server]
${aws_eip.server_eips["prod"].public_ip}

[all:vars]
ansible_user=admin
ansible_ssh_private_key_file=~/.ssh/mykey.pem
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}

# Outputs pour les Elastic IP
output "ci_cd_elastic_ip" {
  description = "Elastic IP du serveur CI/CD"
  value       = aws_eip.server_eips["ci_cd"].public_ip
}

output "dev_elastic_ip" {
  description = "Elastic IP du serveur Development"
  value       = aws_eip.server_eips["dev"].public_ip
}

output "qa_elastic_ip" {
  description = "Elastic IP du serveur QA"
  value       = aws_eip.server_eips["qa"].public_ip
}

output "prod_elastic_ip" {
  description = "Elastic IP du serveur Production"
  value       = aws_eip.server_eips["prod"].public_ip
}

output "all_elastic_ips" {
  description = "Toutes les Elastic IP des serveurs"
  value = {
    for key, eip in aws_eip.server_eips : key => eip.public_ip
  }
}

# ============================================================================
# CONFIGURATION DNS ET SSL/TLS
# ============================================================================

# Zone DNS Route53 principale (commentée pour utiliser OVH DNS)
# resource "aws_route53_zone" "main_zone" {
#   name = "jeu-thetiptop.com"
#   
#   tags = {
#     Name        = "${var.project_name}-dns-zone"
#     Project     = var.project_name
#     Environment = "shared"
#   }
# }

# Certificats SSL/TLS via AWS Certificate Manager pour chaque serveur
# resource "aws_acm_certificate" "server_certificates" {
#   for_each = local.instances
#   
#   domain_name       = "${replace(each.key, "_", "-")}.jeu-thetiptop.com"
#   validation_method = "DNS"
#   
#   subject_alternative_names = [
#     "*.${replace(each.key, "_", "-")}.jeu-thetiptop.com"
#   ]
#   
#   lifecycle {
#     create_before_destroy = true
#   }
#   
#   tags = {
#     Name        = "${var.project_name}-${each.key}-cert"
#     Project     = var.project_name
#     Environment = each.value
#   }
# }

# Enregistrements DNS pour la validation des certificats (commenté pour OVH DNS)
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in flatten([
#       for cert_key, cert in aws_acm_certificate.server_certificates : [
#         for dvo in cert.domain_validation_options : {
#           key = "${cert_key}-${dvo.domain_name}"
#           name = dvo.resource_record_name
#           record = dvo.resource_record_value
#           type = dvo.resource_record_type
#           zone_id = aws_route53_zone.main_zone.zone_id
#         }
#       ]
#     ]) : dvo.key => dvo
#   }
#   
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = each.value.zone_id
# }

# Validation des certificats (commentée)
# resource "aws_acm_certificate_validation" "server_cert_validation" {
#   for_each = local.instances
#   
#   certificate_arn = aws_acm_certificate.server_certificates[each.key].arn
#   
#   timeouts {
#     create = "10m"
#   }
#   
#   depends_on = [aws_route53_record.cert_validation]
# }

# Enregistrements DNS A pointant vers les Elastic IP (commenté pour OVH DNS)
# resource "aws_route53_record" "server_dns_records" {
#   for_each = local.instances
#   
#   zone_id = aws_route53_zone.main_zone.zone_id
#   name    = "${replace(each.key, "_", "-")}.jeu-thetiptop.com"
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.server_eips[each.key].public_ip]
# }

# Enregistrement DNS pour le domaine principal (commenté pour OVH DNS)
# resource "aws_route53_record" "main_domain" {
#   zone_id = aws_route53_zone.main_zone.zone_id
#   name    = "jeu-thetiptop.com"
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.server_eips["ci_cd"].public_ip]
# }

# Enregistrement DNS pour www (commenté pour OVH DNS)
# resource "aws_route53_record" "www_domain" {
#   zone_id = aws_route53_zone.main_zone.zone_id
#   name    = "www.jeu-thetiptop.com"
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.server_eips["ci_cd"].public_ip]
# }

# ============================================================================
# OUTPUTS DNS ET SSL (commentés pour OVH DNS)
# ============================================================================

# output "dns_zone_id" {
#   description = "ID de la zone DNS Route 53"
#   value       = aws_route53_zone.main_zone.zone_id
# }

# output "dns_zone_name_servers" {
#   description = "Serveurs de noms pour la zone DNS"
#   value       = aws_route53_zone.main_zone.name_servers
# }

# output "server_domains" {
#   description = "Domaines HTTPS pour chaque serveur"
#   value = {
#     for key, instance in local.instances : key => "https://${replace(key, "_", "-")}.jeu-thetiptop.com"
#   }
# }

# output "ssl_certificates" {
#   description = "ARN des certificats SSL pour chaque serveur"
#   value = {
#     for key, cert in aws_acm_certificate.server_certificates : key => cert.arn
#   }
# }

# output "main_domain" {
#   description = "Domaine principal"
#   value       = "https://jeu-thetiptop.com"
# }