module "PREFIX-LIST-V6" {
  source = "./prefix-list"
  FAMILY = "IPv6"
}


module "TGW" {
  source        = "./tgw"
  TGWPARAMETERS = local.TGW
  AUTHTAGS      = local.AUTHTAGS
}


module "APPLIANCE-VPC" {
  depends_on     = [module.TGW]
  source         = "./vpc"
  VPCPARAMETERS  = local.APPLIANCE-VPC
  AUTHTAGS       = local.AUTHTAGS
  TGW            = module.TGW.TGW
  PREFIX-V6-DATA = module.PREFIX-LIST-V6.PREFIX-V6-DATA
}


module "TGW-ATTACH-APPLIANCE" {
  depends_on    = [module.APPLIANCE-VPC]
  source        = "./tgw-attach"
  count         = can(local.APPLIANCE-VPC.TGWConnection) ? 1 : 0
  VPCPARAMETERS = module.APPLIANCE-VPC.VPC-DATA
  TGW           = module.TGW.TGW
}


module "SPOKE1-CON-VPC" {
  depends_on     = [module.TGW]
  source         = "./vpc"
  VPCPARAMETERS  = local.SPOKE1-CON-VPC
  AUTHTAGS       = local.AUTHTAGS
  TGW            = module.TGW.TGW
  PREFIX-V6-DATA = module.PREFIX-LIST-V6.PREFIX-V6-DATA
}


module "TGW-ATTACH-SPOKE1" {
  depends_on    = [module.SPOKE1-CON-VPC]
  source        = "./tgw-attach"
  count         = can(local.SPOKE1-CON-VPC.TGWConnection) ? 1 : 0
  VPCPARAMETERS = module.SPOKE1-CON-VPC.VPC-DATA
  TGW           = module.TGW.TGW
}


module "SPOKE2-NONCON-VPC" {
  depends_on     = [module.TGW]
  source         = "./vpc"
  VPCPARAMETERS  = local.SPOKE2-NONCON-VPC
  AUTHTAGS       = local.AUTHTAGS
  TGW            = module.TGW.TGW
  PREFIX-V6-DATA = module.PREFIX-LIST-V6.PREFIX-V6-DATA
}


module "TGW-ATTACH-SPOKE2" {
  depends_on    = [module.SPOKE2-NONCON-VPC]
  source        = "./tgw-attach"
  count         = can(local.SPOKE2-NONCON-VPC.TGWConnection) ? 1 : 0
  VPCPARAMETERS = module.SPOKE2-NONCON-VPC.VPC-DATA
  TGW           = module.TGW.TGW
}


module "SPOKE3-NONCON-VPC" {
  depends_on     = [module.TGW]
  source         = "./vpc"
  VPCPARAMETERS  = local.SPOKE3-NONCON-VPC
  AUTHTAGS       = local.AUTHTAGS
  TGW            = module.TGW.TGW
  PREFIX-V6-DATA = module.PREFIX-LIST-V6.PREFIX-V6-DATA
}


module "TGW-ATTACH-SPOKE3" {
  depends_on    = [module.SPOKE3-NONCON-VPC]
  source        = "./tgw-attach"
  count         = can(local.SPOKE3-NONCON-VPC.TGWConnection) ? 1 : 0
  VPCPARAMETERS = module.SPOKE3-NONCON-VPC.VPC-DATA
  TGW           = module.TGW.TGW
}


module "GWLB" {
  depends_on = [module.APPLIANCE-VPC,
    module.SPOKE1-CON-VPC,
    module.SPOKE2-NONCON-VPC,
  module.SPOKE3-NONCON-VPC]
  source = "./gwlb"
  GWLB   = local.GWLB
}


module "TGW-ROUTES" {
  depends_on = [module.GWLB]
  source     = "./tgw-routes"
  TGW        = module.TGW.TGW
  TGW_RT     = module.TGW.TGW_RT
}


module "APPLIANCE-ROUTESROUTE-DEF" {
  depends_on     = [module.GWLB]
  source         = "./appliance-route-def"
  TGWPARAMETERS  = local.TGW
  GWLB           = module.GWLB.GWLB-DATA
  TGW            = module.TGW.TGW
  PREFIX-V6-DATA = module.PREFIX-LIST-V6.PREFIX-V6-DATA
}


module "CONNECTED-ROUTES-DEF" {
  depends_on = [module.GWLB]
  source     = "./connected-routes-def"
  TGW        = module.TGW.TGW
  VPC-DATA   = module.SPOKE1-CON-VPC.VPC-DATA
}



