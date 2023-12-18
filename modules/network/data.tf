# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "oci_core_vcn" "vcn" {
  vcn_id     = var.byo_vcn ? var.byo_vcn_ocid : oci_core_vcn.vcn[0].id
  depends_on = [oci_core_vcn.vcn[0]]
}

data "oci_core_internet_gateways" "igw" {
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
}

data "oci_core_nat_gateways" "ngw" {
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
}

data "oci_core_service_gateways" "sgw" {
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
}

data "oci_core_services" "core_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_core_subnet" "public" {
  subnet_id  = local.public_subnet_ocid
  depends_on = [oci_core_subnet.public[0]]
}

data "oci_core_subnet" "private" {
  subnet_id  = local.private_subnet_ocid
  depends_on = [oci_core_subnet.private[0]]
}