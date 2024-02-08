# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  byo_vcn               = var.byo_vcn && var.ociVcnOcid != "" ? true : false
  create_public_subnet  = local.byo_vcn && var.ociPublicSubnetOcid != "" ? false : true
  public_subnet_ocid    = local.create_public_subnet ? "" : var.ociPublicSubnetOcid
  create_private_subnet = local.byo_vcn && var.ociPrivateSubnetOcid != "" ? false : true
  private_subnet_ocid   = local.create_private_subnet ? "" : var.ociPrivateSubnetOcid
}

module "network" {
  source                  = "./modules/network"
  compartment_id          = local.compartment_ocid
  label_prefix            = local.label_prefix
  byo_vcn                 = local.byo_vcn
  byo_vcn_ocid            = var.ociVcnOcid
  byo_public_subnet_ocid  = local.public_subnet_ocid
  create_public_subnet    = local.create_public_subnet
  byo_private_subnet_ocid = local.private_subnet_ocid
  create_private_subnet   = local.create_private_subnet
}