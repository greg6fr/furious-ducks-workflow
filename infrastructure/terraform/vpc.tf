resource "aws_vpc" "furious_vpc" {
  count      = var.vpc_id == "" ? 1 : 0
  cidr_block = "10.0.0.0/16"

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_subnet" "furious_subnet" {
  count                   = var.subnet_id == "" ? 1 : 0
  vpc_id                  = var.vpc_id != "" ? var.vpc_id : aws_vpc.furious_vpc[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "furious_igw" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = var.vpc_id != "" ? var.vpc_id : aws_vpc.furious_vpc[0].id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "furious_public_rt" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = var.vpc_id != "" ? var.vpc_id : aws_vpc.furious_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.furious_igw[0].id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "furious_rt_assoc" {
  count          = var.subnet_id == "" ? 1 : 0
  subnet_id      = var.subnet_id != "" ? var.subnet_id : aws_subnet.furious_subnet[0].id
  route_table_id = aws_route_table.furious_public_rt[0].id
}

output "vpc_id_created" {
  value       = var.vpc_id != "" ? var.vpc_id : aws_vpc.furious_vpc[0].id
  description = "ID du VPC créé ou existant"
}

output "subnet_id_created" {
  value       = var.subnet_id != "" ? var.subnet_id : aws_subnet.furious_subnet[0].id
  description = "ID du Subnet créé ou existant"
}