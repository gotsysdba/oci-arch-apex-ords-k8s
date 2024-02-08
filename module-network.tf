# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "network" {
  source                  = "./modules/network"
  compartment_id          = local.compartment_ocid
  label_prefix            = local.label_prefix
  byo_vcn                 = var.byo_vcn && var.ociVcnOcid != "" ? true : false
  byo_vcn_ocid            = var.ociVcnOcid
  byo_public_subnet_ocid  = var.ociPublicSubnetOcid
  byo_private_subnet_ocid = var.ociPrivateSubnetOcid
}