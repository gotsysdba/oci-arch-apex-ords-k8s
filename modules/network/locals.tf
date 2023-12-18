# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  create_igw = var.byo_vcn ? length(data.oci_core_internet_gateways.igw.gateways) > 0 ? false : true : true
  create_ngw = var.byo_vcn ? length(data.oci_core_nat_gateways.ngw.nat_gateways) > 0 ? false : true : true
  create_sgw = var.byo_vcn ? length(data.oci_core_service_gateways.sgw.service_gateways) > 0 ? false : true : true
}

locals {
  public_subnet_cidr  = cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 1, 1)
  public_subnet_ocid  = var.create_public_subnet ? oci_core_subnet.public[0].id : var.byo_public_subnet_ocid
  private_subnet_cidr = var.create_public_subnet ? cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 1, 0) : cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 0, 0)
  private_subnet_ocid = var.create_private_subnet ? oci_core_subnet.private[0].id : var.byo_private_subnet_ocid
}