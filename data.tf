# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

// oci_containerengine
data "oci_containerengine_node_pool_option" "images" {
  node_pool_option_id = oci_containerengine_cluster.default_cluster.id
  compartment_id      = local.compartment_ocid
}

// oci_core
data "oci_core_services" "core_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

// oci_identity
data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

data "oci_identity_regions" "identity_regions" {}

data "oci_identity_user" "identity_user" {
  user_id = local.user_ocid
}

// oci_objectstorage
data "oci_objectstorage_namespace" "objectstorage_namespace" {
  compartment_id = local.compartment_ocid
}

// oci_resourcemanager
data "oci_resourcemanager_private_endpoint_reachable_ip" "orm_pe_reachable_ip" {
  count               = local.create_orm_pe ? 1 : 0
  private_endpoint_id = oci_resourcemanager_private_endpoint.orm_pe[0].id
  private_ip          = split(":", oci_containerengine_cluster.default_cluster.endpoints[0].private_endpoint)[0]
}