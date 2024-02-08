# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl
locals {
  public_subnet_ocid  = var.byo_vcn ? var.byo_public_subnet_ocid : oci_core_subnet.public[0].id
  private_subnet_ocid = var.byo_vcn ? var.byo_private_subnet_ocid : oci_core_subnet.private[0].id
}