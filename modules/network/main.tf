# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
  required_version = "~> 1.2"
}

resource "oci_core_vcn" "vcn" {
  count          = var.byo_vcn ? 0 : 1
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = format("%s-vcn", var.label_prefix)
  dns_label      = var.label_prefix
}

// Lock Down Default Sec List
resource "oci_core_default_security_list" "lockdown" {
  count                      = var.byo_vcn ? 0 : 1
  compartment_id             = data.oci_core_vcn.vcn.compartment_id
  display_name               = format("%s-default-sec-list", var.label_prefix)
  manage_default_resource_id = data.oci_core_vcn.vcn.default_security_list_id
}

// Lock Down New Sec List
resource "oci_core_security_list" "lockdown" {
  count          = var.byo_vcn ? 1 : 0
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-lockdown-sec-list", var.label_prefix)
}

resource "oci_core_internet_gateway" "igw" {
  count          = local.create_igw ? 1 : 0
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-igw", var.label_prefix)
  enabled        = "true"
}

resource "oci_core_nat_gateway" "ngw" {
  count          = local.create_ngw ? 1 : 0
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-ngw", var.label_prefix)
  block_traffic  = "false"
}

resource "oci_core_service_gateway" "sgw" {
  count          = local.create_sgw ? 1 : 0
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-sgw", var.label_prefix)
  services {
    service_id = data.oci_core_services.core_services.services.0.id
  }
}

resource "oci_core_default_route_table" "public_route_table" {
  count        = var.byo_vcn ? 0 : 1
  display_name = format("%s-public-route-table", var.label_prefix)
  route_rules {
    description       = "traffic to/from internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = try(oci_core_internet_gateway.igw[0].id, data.oci_core_internet_gateways.igw.gateways[0].id)
  }
  manage_default_resource_id = data.oci_core_vcn.vcn.default_route_table_id
}

resource "oci_core_route_table" "public_route_table" {
  count          = var.byo_vcn ? 1 : 0
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-public-route-table", var.label_prefix)
  route_rules {
    description       = "traffic to/from internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = try(oci_core_internet_gateway.igw[0].id, data.oci_core_internet_gateways.igw.gateways[0].id)
  }
}

resource "oci_core_route_table" "private_route_table" {
  compartment_id = data.oci_core_vcn.vcn.compartment_id
  vcn_id         = data.oci_core_vcn.vcn.id
  display_name   = format("%s-private-route-table", var.label_prefix)
  route_rules {
    description       = "traffic to the internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = try(oci_core_nat_gateway.ngw[0].id, data.oci_core_nat_gateways.ngw.nat_gateways[0].id)
  }
  route_rules {
    description       = "traffic to OCI services"
    destination       = data.oci_core_services.core_services.services.0.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = try(oci_core_service_gateway.sgw[0].id, data.oci_core_service_gateways.sgw.service_gateways[0].id)
  }
}

resource "oci_core_subnet" "public" {
  count                      = var.create_public_subnet ? 1 : 0
  cidr_block                 = local.public_subnet_cidr
  compartment_id             = data.oci_core_vcn.vcn.compartment_id
  vcn_id                     = data.oci_core_vcn.vcn.id
  display_name               = format("%s-public", var.label_prefix)
  dns_label                  = data.oci_core_vcn.vcn.dns_label == null ? null : "publ"
  prohibit_public_ip_on_vnic = false
  route_table_id             = data.oci_core_vcn.vcn.default_route_table_id
}

resource "oci_core_subnet" "private" {
  count                      = var.create_private_subnet ? 1 : 0
  cidr_block                 = local.private_subnet_cidr
  compartment_id             = data.oci_core_vcn.vcn.compartment_id
  vcn_id                     = data.oci_core_vcn.vcn.id
  display_name               = format("%s-private", var.label_prefix)
  dns_label                  = data.oci_core_vcn.vcn.dns_label == null ? null : "priv"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_route_table.id
}