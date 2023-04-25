locals {
  user_data        = fileexists("./config.yaml") ? yamldecode(file("./config.yaml")) : jsondecode(file("./config.json"))
  REGION           = local.user_data.Parameters.Region
  DEPLOYMENTPREFIX = local.user_data.Parameters.DeploymentPrefix

  APPLIANCE-VPC     = local.user_data.Parameters.VPCs.Appliance-VPC
  SPOKE1-CON-VPC    = local.user_data.Parameters.VPCs.Spoke1-Con-VPC
  SPOKE2-NONCON-VPC = local.user_data.Parameters.VPCs.Spoke2-NonCon-VPC
  SPOKE3-NONCON-VPC = local.user_data.Parameters.VPCs.Spoke3-NonCon-VPC

  TGW      = local.user_data.Parameters.Tgw
  GWLB     = local.user_data.Parameters.Gwlb
  AUTHTAGS = local.user_data.Parameters.AuthTags
}




