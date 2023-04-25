variable "FAMILY" {}


resource "aws_ec2_managed_prefix_list" "prefix-list" {
  name           = "Connected IPv6 CIDRs"
  address_family = var.FAMILY
  max_entries    = 10
}


output "PREFIX-V6-DATA" {
  value = aws_ec2_managed_prefix_list.prefix-list
}

