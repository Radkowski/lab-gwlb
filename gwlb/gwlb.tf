variable "GWLB" {}


data "aws_availability_zones" "AZs" {
  state = "available"
}


data "aws_caller_identity" "current" {}


data "aws_vpcs" "gwlb-vpc" {
  tags = {
    Gwlb-enabled = "true"
  }
}


data "aws_subnets" "gwlb-subnets" {
  count = 2
  lifecycle {
    precondition {
      condition     = length(data.aws_vpcs.gwlb-vpc.ids) == 1
      error_message = "Config error - only one VPC must be tagged to deploy GWLB"
    }
  }
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



resource "aws_lb" "gwlb" {
  name                       = var.GWLB.Name
  load_balancer_type         = "gateway"
  subnets                    = [for subnet in data.aws_subnets.gwlb-subnets : subnet.ids[0]]
  enable_deletion_protection = false
  ip_address_type            = "dualstack"
}


resource "aws_lb_target_group" "gwlbtg" {
  name        = join("", [var.GWLB.Name, "-TG"])
  port        = 6081
  protocol    = "GENEVE"
  target_type = "instance"
  vpc_id      = data.aws_vpcs.gwlb-vpc.ids[0]
  health_check {
    protocol = "TCP"
  }
}


resource "aws_lb_listener" "gwlblsnr" {
  load_balancer_arn = aws_lb.gwlb.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlbtg.arn
  }
}


resource "aws_vpc_endpoint_service" "gwlbsrv" {
  acceptance_required        = false
  allowed_principals         = [join(":", ["arn:aws:iam:", data.aws_caller_identity.current.id, "root"])]
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]
}


resource "aws_vpc_endpoint" "gwlbendpoints" {
  count             = 2
  service_name      = aws_vpc_endpoint_service.gwlbsrv.service_name
  subnet_ids        = data.aws_subnets.gwlb-subnets[count.index].ids
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlbsrv.service_type
  vpc_id            = data.aws_vpcs.gwlb-vpc.ids[0]
  tags = {
    Name = join("", [var.GWLB.Name, "-vpce-", tostring(count.index)])
  }
}


output "GWLB-DATA" {
  value = {
    GWLB    = aws_lb.gwlb
    GWLBE   = aws_vpc_endpoint.gwlbendpoints
    SUBNETS = data.aws_subnets.gwlb-subnets
    SUBNETS = [for subnet in data.aws_subnets.gwlb-subnets : subnet.ids[0]]
  }
}
