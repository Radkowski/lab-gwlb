variable "VPCPARAMETERS" {}
variable "TGW" {}



data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.VPCPARAMETERS.VPC_INFO.id]
  }
  tags = {
    Tgw-eni = "true"
  }
}


data "aws_subnet" "subnet_azs" {
  count = 2
  id    = data.aws_subnets.subnets.ids[count.index]
}



resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attach" {
  subnet_ids         = [data.aws_subnets.subnets.ids[0], data.aws_subnets.subnets.ids[1]]
  transit_gateway_id = var.TGW
  ipv6_support       = "enable"
  vpc_id             = var.VPCPARAMETERS.VPC_INFO.id
  lifecycle {
    precondition {
      condition     = data.aws_subnet.subnet_azs[0].availability_zone != data.aws_subnet.subnet_azs[1].availability_zone
      error_message = "Config error - Subnets defined in TGWConnection section must be in differemnt AZs"

    }
  }
  tags = {
    Name   = join("", ["To-", var.VPCPARAMETERS.VPC_NAME])
    Def-gw = (var.VPCPARAMETERS.VPC_TYPE == "Hub" ? true : false)

  }
}


