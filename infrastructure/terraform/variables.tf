variable "region" {
  description = "AWS region"
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name for tagging"
  default     = "furious-ducks"
}

variable "ami_id" {
  description = "AMI ID for Debian 12 EC2 instance"
  default     = "ami-095f7a7548d56a223"
}

variable "instance_type" {
  description = "Instance type"
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID for EC2"
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID"
  default     = ""
}