data "aws_availability_zones" "AZs" {
  state = "available"
}

variable "VPCPARAMETERS" {

  description = "List of VPC paramaters"
  validation {
    condition     = length(var.VPCPARAMETERS.PrivateSubnetNames) >= 2
    error_message = "Number of private subnets must be 2 or greater"
  }

}

variable "AUTHTAGS" {}
variable "TGW" {}
variable "PREFIX-V6-DATA" {}


locals {
  DEPLOY_PUBLIC = can(var.VPCPARAMETERS.PublicSubnetNames) ? true : false
}


resource "aws_vpc" "RadLabVPC" {
  cidr_block                       = var.VPCPARAMETERS.CIDR
  instance_tenancy                 = "default"
  enable_dns_hostnames             = "true"
  assign_generated_ipv6_cidr_block = "true"
  tags = {
    Name          = join("", [var.VPCPARAMETERS.Name, "-VPC"])
    Tgw-connected = (can(var.VPCPARAMETERS.TGWConnection))
    Gwlb-enabled  = (can(var.VPCPARAMETERS.GWLBConnection))
  }
}


resource "aws_subnet" "Pub-Dual-Subnet" {
  count                           = local.DEPLOY_PUBLIC ? 2 : 0
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index)
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true
  tags = {
    Name       = join("-", [var.VPCPARAMETERS.Name, var.VPCPARAMETERS.PublicSubnetNames[count.index]])
    Identifier = var.VPCPARAMETERS.PublicSubnetNames[count.index]
    Public     = true
  }
}


resource "aws_subnet" "Priv-Dual-Subnet" {
  count                           = length(var.VPCPARAMETERS.PrivateSubnetNames)
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index + 2)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index + 2)
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
  tags = {
    Name       = join("-", [var.VPCPARAMETERS.Name, var.VPCPARAMETERS.PrivateSubnetNames[count.index]])
    Identifier = var.VPCPARAMETERS.PrivateSubnetNames[count.index]
    Tgw-eni    = (contains(try(var.VPCPARAMETERS.TGWConnection, []), var.VPCPARAMETERS.PrivateSubnetNames[count.index]))
    Gwlb-eni   = (contains(try(var.VPCPARAMETERS.GWLBConnection, []), var.VPCPARAMETERS.PrivateSubnetNames[count.index]))
    VirtApp    = (contains(try(var.VPCPARAMETERS.VirtApp, []), var.VPCPARAMETERS.PrivateSubnetNames[count.index]))
  }
}


resource "aws_internet_gateway" "igw" {
  count  = local.DEPLOY_PUBLIC ? 1 : 0
  vpc_id = aws_vpc.RadLabVPC.id
  tags   = merge(var.AUTHTAGS, { Name = join("", [var.VPCPARAMETERS.Name, "IGW"]) })
}


resource "aws_eip" "natgw_ip" {
  count      = local.DEPLOY_PUBLIC ? 2 : 0
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = join("", [var.VPCPARAMETERS.Name, "-NATGW-IP"])
  }
}


resource "aws_nat_gateway" "natgw" {
  count         = local.DEPLOY_PUBLIC ? 2 : 0
  allocation_id = aws_eip.natgw_ip[count.index].id
  subnet_id     = aws_subnet.Pub-Dual-Subnet[count.index].id
  depends_on    = [aws_internet_gateway.igw, aws_eip.natgw_ip]
  tags = {
    Name     = join("", [var.VPCPARAMETERS.Name, "-NATGW"])
    Location = data.aws_availability_zones.AZs.names[count.index % 2]
  }
}


resource "aws_egress_only_internet_gateway" "egw" {
  count  = local.DEPLOY_PUBLIC ? 1 : 0
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.VPCPARAMETERS.Name, "-EIGW"])
  }
}


resource "aws_ssm_parameter" "store-egress-only" {
  count = local.DEPLOY_PUBLIC ? 1 : 0
  name  = join("", ["/custom/RadkowskiLab/", aws_vpc.RadLabVPC.id, "/eigw"])
  type  = "String"
  value = one(aws_egress_only_internet_gateway.egw[*].id)
}


resource "aws_route_table" "PubRoute" {
  count      = local.DEPLOY_PUBLIC ? 1 : 0
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("-", [var.VPCPARAMETERS.Name, "Public-RT"])
  }
}


resource "aws_route" "pub1" {
  count                  = local.DEPLOY_PUBLIC ? 1 : 0
  depends_on             = [aws_route_table.PubRoute]
  route_table_id         = one(aws_route_table.PubRoute[*].id)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = one(aws_internet_gateway.igw[*].id)
}


resource "aws_route" "pub1_v6" {
  count                       = local.DEPLOY_PUBLIC ? 1 : 0
  depends_on                  = [aws_route_table.PubRoute]
  route_table_id              = one(aws_route_table.PubRoute[*].id)
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = one(aws_internet_gateway.igw[*].id)
}


resource "aws_route_table" "PrivRoute" {
  count      = length(var.VPCPARAMETERS.PrivateSubnetNames)
  depends_on = [aws_vpc.RadLabVPC, aws_nat_gateway.natgw, aws_egress_only_internet_gateway.egw]
  vpc_id     = aws_vpc.RadLabVPC.id
  timeouts {
    create = "5m"
  }
  tags = {
    Name = join("-", [var.VPCPARAMETERS.Name, var.VPCPARAMETERS.PrivateSubnetNames[count.index], "RT"])
  }
}


resource "aws_route" "priv1" {
  count = local.DEPLOY_PUBLIC && var.VPCPARAMETERS.Type == "Spoke" ? length(var.VPCPARAMETERS.PrivateSubnetNames) : 0
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_route_table.PrivRoute, aws_nat_gateway.natgw]
  route_table_id         = aws_route_table.PrivRoute[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw[count.index % 2].id
}


resource "aws_route" "priv2" {
  count = local.DEPLOY_PUBLIC && var.VPCPARAMETERS.Type == "Spoke" ? length(var.VPCPARAMETERS.PrivateSubnetNames) : 0
  timeouts {
    create = "5m"
  }
  depends_on                  = [aws_route_table.PrivRoute, aws_egress_only_internet_gateway.egw]
  route_table_id              = aws_route_table.PrivRoute[count.index].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = one(aws_egress_only_internet_gateway.egw[*].id)
}


resource "aws_route_table_association" "PubAssociation" {
  count          = local.DEPLOY_PUBLIC ? 2 : 0
  subnet_id      = aws_subnet.Pub-Dual-Subnet[count.index].id
  route_table_id = one(aws_route_table.PubRoute[*].id)
}


resource "aws_route_table_association" "PrivAssociation" {
  count          = length(var.VPCPARAMETERS.PrivateSubnetNames)
  subnet_id      = aws_subnet.Priv-Dual-Subnet[count.index].id
  route_table_id = aws_route_table.PrivRoute[count.index].id
}


resource "aws_ec2_managed_prefix_list_entry" "ipv6_entry" {
  count          = (var.VPCPARAMETERS.Type == "Spoke" && can(var.VPCPARAMETERS.TGWConnection)) ? 1 : 0
  cidr           = aws_vpc.RadLabVPC.ipv6_cidr_block
  description    = "Somedesc"
  prefix_list_id = var.PREFIX-V6-DATA.id
}



output "VPCID" {
  value = aws_vpc.RadLabVPC.id
}


output "PUBSUBNETSID" {
  value = aws_subnet.Pub-Dual-Subnet
}

output "PRIVSUBNETSID" {
  value = aws_subnet.Priv-Dual-Subnet
}

output "ROUTETABLES" {
  value = compact(concat(aws_route_table.PrivRoute[*].id, [one(aws_route_table.PubRoute[*].id)]))
}

output "VPC-DATA" {
  value = {
    "VPC_INFO" : aws_vpc.RadLabVPC
    "VPC_NAME" : var.VPCPARAMETERS.Name
    "VPC_TYPE" : var.VPCPARAMETERS.Type
    "SUBNETS" : concat(aws_subnet.Pub-Dual-Subnet, aws_subnet.Priv-Dual-Subnet)
    "ROUTES" : compact(concat(aws_route_table.PrivRoute[*].id, [one(aws_route_table.PubRoute[*].id)]))
    "PUBLIC" : local.DEPLOY_PUBLIC
    "PRIV_SUB_COUNT" = length(var.VPCPARAMETERS.PrivateSubnetNames)
  }
}







