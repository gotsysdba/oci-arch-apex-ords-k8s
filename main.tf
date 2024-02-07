# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

// random
resource "random_pet" "label" {
  length = 1
}

resource "random_integer" "label_unique" {
  // Used with random_pet.label for tenancy wide resources
  min = 1
  max = 50000
}

// oci_core
resource "oci_core_public_ip" "service_lb" {
  count          = var.service_lb_is_public ? 1 : 0
  compartment_id = local.compartment_ocid
  display_name   = format("%s-rsvd-ip", local.label_prefix)
  lifetime       = "RESERVED"
  # The below ensures the RSVD IP will be destroyed
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [private_ip_id]
  }
}

resource "oci_identity_dynamic_group" "node_dynamic_group" {
  compartment_id = var.ociTenancyOcid
  name           = format("%s-worker-nodes-dyngrp", local.label_prefix)
  description    = format("%s Dynamic Group - OKE Nodes", local.label_prefix)
  matching_rule = format("All {instance.compartment.id='%s',tag.%s.value='%s'}",
    local.compartment_ocid, local.tag_OKEclusterNameKey, local.tag_OKEclusterNameVal
  )
  provider = oci.home_region
}

resource "oci_identity_policy" "worker_node_policies" {
  compartment_id = local.compartment_ocid
  name           = format("%s-worker-nodes-policy", local.label_prefix)
  description    = format("%s Policy - Worker Nodes", local.label_prefix)
  statements = [
    format("allow dynamic-group %s to manage buckets in compartment id %s", oci_identity_dynamic_group.node_dynamic_group.name, local.compartment_ocid),
    format("allow dynamic-group %s to manage objects in compartment id %s", oci_identity_dynamic_group.node_dynamic_group.name, local.compartment_ocid),
    format("allow dynamic-group %s to manage autonomous-database-family in compartment id %s", oci_identity_dynamic_group.node_dynamic_group.name, local.compartment_ocid),
  ]
  provider = oci.home_region
}

// oci_identity_tag
resource "oci_identity_tag_namespace" "tag_namespace" {
  compartment_id = local.compartment_ocid
  description    = format("%s Tag Namespace", local.label_prefix)
  name           = format("%s-%s", local.label_prefix, random_integer.label_unique.result)
  provider       = oci.home_region
}

resource "oci_identity_tag" "identity_tag_OKEclusterName" {
  description      = "OKE Cluster Name"
  name             = format("%s-OKEclusterName", local.label_prefix)
  tag_namespace_id = oci_identity_tag_namespace.tag_namespace.id
  provider         = oci.home_region
}

// oci_resourcemanager
resource "oci_resourcemanager_private_endpoint" "orm_pe" {
  count          = local.create_orm_pe ? 1 : 0
  compartment_id = local.compartment_ocid
  vcn_id         = module.network.vcn_ocid
  display_name   = format("%s-orm-pe", var.label_prefix)
  description    = "Private Endpoint for Resource Manager"
  subnet_id      = module.network.private_subnet_ocid
}

// OKE
resource "oci_containerengine_cluster" "default_cluster" {
  compartment_id     = local.compartment_ocid
  kubernetes_version = format("v%s", var.oke_version)
  name               = local.oke_cluster_name
  vcn_id             = module.network.vcn_ocid
  type               = "ENHANCED_CLUSTER"

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = var.oke_api_is_public
    subnet_id            = module.network.public_subnet_ocid // Avoid Destruction by switching; control via NSGs
    nsg_ids              = [oci_core_network_security_group.oke_api_endpoint.id]
  }

  image_policy_config {
    is_policy_enabled = false
  }
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = "false"
    }
    persistent_volume_config {
      freeform_tags = {
        "OKEclusterName" = local.oke_cluster_name
      }
    }
    service_lb_config {
      freeform_tags = {
        "OKEclusterName" = local.oke_cluster_name
      }
    }
    service_lb_subnet_ids = [module.network.public_subnet_ocid]
  }
  freeform_tags = {
    "OKEclusterName" = local.oke_cluster_name
  }
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

resource "oci_containerengine_node_pool" "default_node_pool_details" {
  cluster_id         = oci_containerengine_cluster.default_cluster.id
  compartment_id     = local.compartment_ocid
  kubernetes_version = format("v%s", var.oke_version)
  name               = format("%s-np-default", local.label_prefix)
  initial_node_labels {
    key   = "name"
    value = local.oke_cluster_name
  }
  node_config_details {
    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }
    dynamic "placement_configs" {
      for_each = local.availability_domains
      iterator = ad
      content {
        availability_domain = ad.value
        subnet_id           = module.network.private_subnet_ocid
      }
    }
    size = var.oke_worker_pool_size

    nsg_ids = concat(
      [oci_core_network_security_group.oke_workers.id], [for nsg in oci_core_network_security_group.oke_workers_lockdown : nsg.id]
    )
    defined_tags = { (local.tag_OKEclusterNameKey) = local.tag_OKEclusterNameVal }
  }
  node_eviction_node_pool_settings {
    eviction_grace_duration = "PT1H"
  }

  node_shape = var.oke_node_worker_shape
  node_shape_config {
    memory_in_gbs = var.oke_node_worker_ocpu * 16
    ocpus         = var.oke_node_worker_ocpu
  }
  node_pool_cycling_details {
    is_node_cycling_enabled = true
    maximum_surge           = "50%"
    maximum_unavailable     = "50%"
  }
  node_source_details {
    image_id                = local.oke_selected_worker_image
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = 50
  }
  defined_tags = { (local.tag_OKEclusterNameKey) = local.tag_OKEclusterNameVal }
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
  depends_on = [oci_core_network_security_group_security_rule.oke]
}