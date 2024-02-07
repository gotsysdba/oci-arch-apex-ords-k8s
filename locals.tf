# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

// House-Keeping
locals {
  compartment_ocid = var.ociCompartmentOcid != "" ? var.ociCompartmentOcid : var.ociTenancyOcid
  label_prefix     = var.label_prefix != "" ? lower(var.label_prefix) : lower(random_pet.label.id)
}

locals {
  oke_cluster_name = format("%s-oke", local.label_prefix)
  create_orm_pe    = var.orm_install ? contains(local.oke_api_endpoint_allowed_cidrs, "0.0.0.0/0") ? false : true : false
}

// ADs
locals {
  // Tenancy-specific availability domains in region
  ads = data.oci_identity_availability_domains.all.availability_domains

  // Map of parsed availability domain numbers to tenancy-specific names
  // Used by resources with AD placement for generic selection
  ad_numbers_to_names = local.ads != null ? {
    for ad in local.ads : parseint(substr(ad.name, -1, -1), 10) => ad.name
  } : { -1 : "" } # Fallback handles failure when unavailable but not required

  // List of availability domain numbers in region
  // Used to intersect desired AD lists against presence in region
  ad_numbers = local.ads != null ? sort(keys(local.ad_numbers_to_names)) : []

  availability_domains = compact([for ad_number in tolist(local.ad_numbers) :
    lookup(local.ad_numbers_to_names, ad_number, null)
  ])
}

// OKE Images
locals {
  oke_worker_images = try({
    for k, v in data.oci_containerengine_node_pool_option.images.sources : v.image_id => merge(
      try(element(regexall("OKE-(?P<k8s_version>[0-9\\.]+)-(?P<build>[0-9]+)", v.source_name), 0), { k8s_version = "none" }),
      {
        arch        = length(regexall("aarch64", v.source_name)) > 0 ? "aarch64" : "x86_64"
        image_type  = length(regexall("OKE", v.source_name)) > 0 ? "oke" : "platform"
        is_gpu      = length(regexall("GPU", v.source_name)) > 0
        os          = trimspace(replace(element(regexall("^[a-zA-Z-]+", v.source_name), 0), "-", " "))
        os_version  = element(regexall("[0-9\\.]+", v.source_name), 0)
        source_name = v.source_name
      },
    )
  }, {})

  oke_selected_worker_image = [for key, value in local.oke_worker_images : key if
  value["image_type"] == "oke" && value["arch"] == "x86_64" && value["os_version"] == "8.8" && value["k8s_version"] == var.oke_version][0]
}

// Tags
locals {
  tag_OKEclusterNameKey = format("%s.%s", oci_identity_tag_namespace.tag_namespace.name, oci_identity_tag.identity_tag_OKEclusterName.name)
  tag_OKEclusterNameVal = local.oke_cluster_name
}

// Region Mapping
locals {
  region_map = {
    for r in data.oci_identity_regions.identity_regions.regions : r.name => r.key
  }
  image_region = lookup(
    local.region_map,
    var.ociRegionIdentifier
  )
}

locals {
  # Port numbers
  all_ports               = -1
  apiserver_port          = 6443
  fss_nfs_portmapper_port = 111
  fss_nfs_port_min        = 2048
  fss_nfs_port_max        = 2050
  health_check_port       = 10256
  kubelet_api_port        = 10250
  control_plane_port      = 12250
  node_port_min           = 30000
  node_port_max           = 32767
  ssh_port                = 22

  # Protocols
  # See https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
  all_protocols = "all"
  icmp_protocol = 1
  tcp_protocol  = 6
  udp_protocol  = 17

  anywhere          = "0.0.0.0/0"
  rule_type_nsg     = "NETWORK_SECURITY_GROUP"
  rule_type_cidr    = "CIDR_BLOCK"
  rule_type_service = "SERVICE_CIDR_BLOCK"

  # Oracle Services Network (OSN)
  osn = data.oci_core_services.core_services.services.0.cidr_block
}