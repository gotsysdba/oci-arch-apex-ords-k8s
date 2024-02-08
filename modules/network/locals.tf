# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  public_subnet_cidr  = cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 1, 1)
  public_subnet_ocid  = var.create_public_subnet ? oci_core_subnet.public[0].id : var.byo_public_subnet_ocid
  private_subnet_cidr = var.create_public_subnet ? cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 1, 0) : cidrsubnet(one(data.oci_core_vcn.vcn.cidr_blocks), 0, 0)
  private_subnet_ocid = var.create_private_subnet ? oci_core_subnet.private[0].id : var.byo_private_subnet_ocid
}