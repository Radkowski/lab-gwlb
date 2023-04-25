variable "TGWPARAMETERS" {}
variable "AUTHTAGS" {}



resource "aws_ec2_transit_gateway" "MainTGW" {
  description                     = "MainTGW"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  tags = {
    Name = join("-", [var.TGWPARAMETERS.Name, "TGW"])
  }
}



output "TGW" {
  value = aws_ec2_transit_gateway.MainTGW.id
}


output "TGW_RT" {
  value = aws_ec2_transit_gateway.MainTGW.propagation_default_route_table_id
}
