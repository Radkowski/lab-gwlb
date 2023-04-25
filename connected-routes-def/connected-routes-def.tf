variable "TGW" {}
variable "VPC-DATA" {}


locals {
  ROUTES         = var.VPC-DATA.ROUTES
  PRIV_SUB_COUNT = var.VPC-DATA.PRIV_SUB_COUNT
}



resource "aws_route" "tgw-routes" {
  timeouts {
    create = "5m"
  }
  count                  = local.PRIV_SUB_COUNT
  route_table_id         = local.ROUTES[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.TGW
}


resource "aws_route" "tgw-routes-v6" {
  timeouts {
    create = "5m"
  }
  count                       = local.PRIV_SUB_COUNT
  route_table_id              = local.ROUTES[count.index]
  destination_ipv6_cidr_block = "::/0"
  transit_gateway_id          = var.TGW
}







