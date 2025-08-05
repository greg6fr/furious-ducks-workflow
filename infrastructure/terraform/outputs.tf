# Outputs placeholder
output "ci_cd_public_ip" {
  value = aws_instance.servers["ci_cd"].public_ip
}

output "dev_public_ip" {
  value = aws_instance.servers["dev"].public_ip
}

output "qa_public_ip" {
  value = aws_instance.servers["qa"].public_ip
}

output "prod_public_ip" {
  value = aws_instance.servers["prod"].public_ip
}