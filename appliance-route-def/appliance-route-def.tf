variable "TGWPARAMETERS" {}
variable "GWLB" {}
variable "TGW" {}
variable "PREFIX-V6-DATA" {}


data "aws_availability_zones" "AZs" {
  state = "available"
}


data "aws_vpcs" "connected-vpc" {
  tags = {
    Gwlb-enabled  = "false"
    Tgw-connected = "true"
  }
}


data "aws_vpcs" "gwlb-vpc" {
  tags = {
    Gwlb-enabled = "true"
  }
}


data "aws_ec2_transit_gateway_attachments" "tgw-attach" {
  filter {
    name   = "transit-gateway-id"
    values = [var.TGW]
  }
  filter {
    name   = "resource-type"
    values = ["vpc"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  tags = {
    Def-gw = "true"
  }
}


data "aws_nat_gateways" "natgws" {
  count  = 2
  vpc_id = data.aws_vpcs.gwlb-vpc.ids[0]
  filter {
    name   = "state"
    values = ["available"]
  }
  tags = {
    Location = data.aws_availability_zones.AZs.names[count.index]
  }
}


data "aws_internet_gateway" "igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpcs.gwlb-vpc.ids[0]]
  }
}


data "aws_subnets" "gwlb-subnets" {
  count = 2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.gwlb-vpc.ids[0]]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.AZs.names[count.index]]
  }
  tags = {
    Gwlb-eni = "true"
  }
}


data "aws_subnets" "tgw-subnets" {
  count = 2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.gwlb-vpc.ids[0]]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.AZs.names[count.index]]
  }
  tags = {
    Tgw-eni = "true"
  }
}


data "aws_subnets" "app-subnets" {
  count = 2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.gwlb-vpc.ids[0]]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.AZs.names[count.index]]
  }
  tags = {
    VirtApp = "true"
  }
}


data "aws_subnets" "pub-subnets" {
  count = 2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.gwlb-vpc.ids[0]]
  }
  filter {
    name   = "availability-zone"
    values = [data.aws_availability_zones.AZs.names[count.index]]
  }
  tags = {
    Public = "true"
  }
}


data "aws_route_table" "gwlb-routes" {
  count     = 2
  subnet_id = flatten(data.aws_subnets.gwlb-subnets[*].ids)[count.index]
}


data "aws_route_table" "tgw-routes" {
  count     = 2
  subnet_id = flatten(data.aws_subnets.tgw-subnets[*].ids)[count.index]
}


data "aws_route_table" "pub-routes" {
  count     = 2
  subnet_id = flatten(data.aws_subnets.pub-subnets[*].ids)[count.index]
}


data "aws_route_table" "app-routes" {
  count     = 2
  subnet_id = flatten(data.aws_subnets.app-subnets[*].ids)[count.index]
}


locals {
  tgw            = var.TGW
  tgw_attach     = data.aws_ec2_transit_gateway_attachments.tgw-attach.ids[0]
  gwlbe          = [for s in var.GWLB.GWLBE : s.id]
  summ_connected = var.TGWPARAMETERS.Summarise_connected
  ipv6_connected = flatten(data.aws_vpcs.connected-vpc[*].ids)
  natgws         = flatten(data.aws_nat_gateways.natgws[*].ids)
  igw            = data.aws_internet_gateway.igw.internet_gateway_id

  subnets = {
    tgw-subnets  = flatten(data.aws_subnets.tgw-subnets[*].ids)
    gwlb-subnets = flatten(data.aws_subnets.gwlb-subnets[*].ids)
    app-subnets  = flatten(data.aws_subnets.app-subnets[*].ids)
    pub-subnets  = flatten(data.aws_subnets.pub-subnets[*].ids)
  }

  routes = {
    tgw-routes  = flatten(data.aws_route_table.tgw-routes[*].route_table_id)
    gwlb-routes = flatten(data.aws_route_table.gwlb-routes[*].route_table_id)
    app-routes  = flatten(data.aws_route_table.app-routes[*].route_table_id)
    pub-routes  = flatten(data.aws_route_table.pub-routes[*].route_table_id)
  }
}



resource "aws_route" "tgw-routes-1" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.tgw-routes)
  route_table_id         = local.routes.tgw-routes[count.index]
  destination_cidr_block = local.summ_connected
  transit_gateway_id     = local.tgw
}


resource "aws_route" "tgw-routes-2" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.tgw-routes)
  route_table_id         = local.routes.tgw-routes[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.gwlbe[count.index % 2]
}


resource "aws_route" "tgw-routes-3" {
  timeouts {
    create = "5m"
  }
  count                      = length(local.routes.tgw-routes)
  route_table_id             = local.routes.tgw-routes[count.index]
  destination_prefix_list_id = var.PREFIX-V6-DATA.id
  transit_gateway_id         = local.tgw
}


resource "aws_route" "gwlb-routes-1" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.gwlb-routes)
  route_table_id         = local.routes.gwlb-routes[count.index]
  destination_cidr_block = local.summ_connected
  transit_gateway_id     = local.tgw
}


resource "aws_route" "gwlb-routes-2" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.gwlb-routes)
  route_table_id         = local.routes.gwlb-routes[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.natgws[count.index % 2]
}


resource "aws_route" "gwlb-routes-3" {
  timeouts {
    create = "5m"
  }
  count                      = length(local.routes.gwlb-routes)
  route_table_id             = local.routes.gwlb-routes[count.index]
  destination_prefix_list_id = var.PREFIX-V6-DATA.id
  transit_gateway_id         = local.tgw
}


resource "aws_route" "app-routes-1" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.app-routes)
  route_table_id         = local.routes.app-routes[count.index]
  destination_cidr_block = local.summ_connected
  transit_gateway_id     = local.tgw
}


resource "aws_route" "app-routes-2" {
  timeouts {
    create = "5m"
  }
  count                  = length(local.routes.app-routes)
  route_table_id         = local.routes.app-routes[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.natgws[count.index % 2]
}


resource "aws_route" "app-routes-3" {
  timeouts {
    create = "5m"
  }
  count                      = length(local.routes.app-routes)
  route_table_id             = local.routes.app-routes[count.index]
  destination_prefix_list_id = var.PREFIX-V6-DATA.id
  transit_gateway_id         = local.tgw
}




