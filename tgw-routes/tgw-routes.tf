variable "TGW" {}
variable "TGW_RT" {}

locals {
  def_gw_cidrs = ["0.0.0.0/0", "::/0"]
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


resource "aws_ec2_transit_gateway_route" "ipv4_route" {
  count                          = 2
  destination_cidr_block         = local.def_gw_cidrs[count.index]
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachments.tgw-attach.ids[0]
  transit_gateway_route_table_id = var.TGW_RT
  lifecycle {
    precondition {
      condition     = length(data.aws_ec2_transit_gateway_attachments.tgw-attach.ids) == 1
      error_message = "Config error - only one TGW attachment must be tagged as default GW"
    }
  }
}


