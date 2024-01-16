# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

#########################################################################
# Variable NSGs
#########################################################################
locals {
  oke_api_endpoint_allowed_cidrs = split(",", replace(var.oke_api_endpoint_allowed_cidrs, "/\\s+/", ""))
  service_lb_allowed_cidrs       = split(",", replace(var.service_lb_allowed_cidrs, "/\\s+/", ""))
  service_lb_allowed_ports       = split(",", replace(var.service_lb_allowed_ports, "/\\s+/", ""))
}

locals {
  oke_api_endpoint_cidr_rules = var.oke_api_is_public ? {
    for allowed_cidr in local.oke_api_endpoint_allowed_cidrs :
    "Allow custom ingress to kube-apiserver from ${allowed_cidr}" => {
      protocol = local.tcp_protocol, port = local.apiserver_port, source = allowed_cidr, source_type = local.rule_type_cidr
    }
  } : {}

  service_lb_rules = flatten([for cidr in local.service_lb_allowed_cidrs : [
    for port in local.service_lb_allowed_ports :
    { cidr = cidr, port = port }]
  ])

  service_lb_cidr_port_rules = var.service_lb_is_public ? {
    for rule in local.service_lb_rules :
    "Allow custom ingress to Load Balancer port ${rule.port} from ${rule.cidr}" => {
      protocol = local.tcp_protocol, port = rule.port, source = rule.cidr, source_type = local.rule_type_cidr
    }
  } : {}

  worker_internet_lookup_rules = flatten([for host in local.dns_names : [
    for ip in data.dns_a_record_set.worker_internet_ips["${host}"].addrs :
    { hostname = host, cidr = format("%s/32", ip) }]
  ])

  worker_internet_local_rules = flatten([for service, ips in local.worker_egress_ip : [
      for ip in ips :
      { hostname = service, cidr = ip }]
  ])

  worker_internet_ip_rules = {
    for rule in concat(local.worker_internet_local_rules, local.worker_internet_lookup_rules) :
    "Worker to ${rule.hostname} (${rule.cidr})" => {
      protocol = local.all_protocols, port = local.all_ports, destination = rule.cidr, destination_type = local.rule_type_cidr
    }
  }
}

#########################################################################
# Static NSGs - Mess with these at your peril
#########################################################################
locals {
  oke_api_endpoint_default_rules = {
    "API Endpoint from Workers." : {
      protocol = local.tcp_protocol, port = local.apiserver_port,
      source   = module.network.private_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Control Plane from Workers." : {
      protocol = local.tcp_protocol, port = local.control_plane_port,
      source   = module.network.private_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "API Endpoint Path Discovery - Ingress." : {
      protocol = local.icmp_protocol, source = module.network.private_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Control Plane to OKE Services." : {
      protocol    = local.tcp_protocol, port = 443,
      destination = data.oci_core_services.core_services.services.0.cidr_block, destination_type = local.rule_type_service
    },
    "API Endpoint to Workers" : {
      protocol    = local.tcp_protocol, port = local.all_ports
      destination = module.network.private_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
    "API Endpoint Path Discovery - Egress." : {
      protocol = local.icmp_protocol, destination = module.network.private_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
  }

  oke_workers_default_rules = {
    "Workers from Workers." : {
      protocol = local.all_protocols, port = local.all_ports,
      source   = module.network.private_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Workers from Load Balancer (Health Checks)." : {
      protocol = local.tcp_protocol, port = local.health_check_port,
      source   = module.network.public_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Workers from Load Balancer." : {
      protocol = local.tcp_protocol, port_min = local.node_port_min, port_max = local.node_port_max,
      source   = module.network.public_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Workers from Control Plane." : {
      protocol = local.tcp_protocol, port = local.all_ports,
      source   = module.network.public_subnet_cidr_block, source_type = local.rule_type_cidr
    },
    "Workers Path Discovery - Ingress." : {
      protocol = local.icmp_protocol, source = module.network.vcn_cidr_block, source_type = local.rule_type_cidr
    },
    "Workers to Workers." : {
      protocol    = local.all_protocols, port = local.all_ports,
      destination = module.network.private_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
    "Workers to API Endpoint." : {
      protocol    = local.tcp_protocol, port = local.apiserver_port,
      destination = module.network.public_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
    "Workers to Control Plane." : {
      protocol    = local.tcp_protocol, port = local.control_plane_port,
      destination = module.network.public_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
    "Workers to OKE Services." : {
      protocol    = local.tcp_protocol, port = local.all_ports, port_min = 443, port_max = 443,
      destination = data.oci_core_services.core_services.services.0.cidr_block, destination_type = local.rule_type_service
    },
  }

  service_lb_default_rules = var.service_lb_is_public ? {
    "Load Balancer from Workers (Health Checks)." : {
      protocol    = local.tcp_protocol, port = local.health_check_port,
      destination = module.network.private_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
    "Load Balancer from Workers." : {
      protocol    = local.tcp_protocol, port_min = local.node_port_min, port_max = local.node_port_max,
      destination = module.network.private_subnet_cidr_block, destination_type = local.rule_type_cidr
    },
  } : {}
}

#########################################################################
# Helpers
#########################################################################
locals {
  # Dynamic map of all NSG rules for enabled NSGs
  all_rules = { for x, y in merge(
    { for k, v in local.oke_api_endpoint_default_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.oke_api_endpoint.id }) },
    { for k, v in local.oke_api_endpoint_cidr_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.oke_api_endpoint.id }) },
    { for k, v in local.oke_workers_default_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.oke_workers.id }) },
    { for k, v in local.worker_internet_ip_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.oke_workers.id }) },
    { for k, v in local.service_lb_default_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.service_lb[0].id }) },
    { for k, v in local.service_lb_cidr_port_rules : k => merge(v, { "nsg_id" = oci_core_network_security_group.service_lb[0].id }) },
    ) : x => merge(y, {
      description               = x
      network_security_group_id = lookup(y, "nsg_id")
      direction                 = contains(keys(y), "source") ? "INGRESS" : "EGRESS"
      protocol                  = lookup(y, "protocol")
      source                    = lookup(y, "source", null)
      source_type               = lookup(y, "source_type", null)
      destination               = lookup(y, "destination", null)
      destination_type          = lookup(y, "destination_type", null)
  }) }
}

#########################################################################
# Implement
#########################################################################
resource "oci_core_network_security_group_security_rule" "oke" {
  for_each                  = local.all_rules
  stateless                 = false
  description               = each.value.description
  destination               = each.value.destination
  destination_type          = each.value.destination_type
  direction                 = each.value.direction
  network_security_group_id = each.value.network_security_group_id
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = each.value.source_type

  dynamic "tcp_options" {
    for_each = (tostring(each.value.protocol) == tostring(local.tcp_protocol) &&
      tonumber(lookup(each.value, "port", 0)) != local.all_ports ? [each.value] : []
    )
    content {
      destination_port_range {
        min = tonumber(lookup(tcp_options.value, "port_min", lookup(tcp_options.value, "port", 0)))
        max = tonumber(lookup(tcp_options.value, "port_max", lookup(tcp_options.value, "port", 0)))
      }
    }
  }

  dynamic "udp_options" {
    for_each = (tostring(each.value.protocol) == tostring(local.udp_protocol) &&
      tonumber(lookup(each.value, "port", 0)) != local.all_ports ? [each.value] : []
    )
    content {
      destination_port_range {
        min = tonumber(lookup(udp_options.value, "port_min", lookup(udp_options.value, "port", 0)))
        max = tonumber(lookup(udp_options.value, "port_max", lookup(udp_options.value, "port", 0)))
      }
    }
  }

  dynamic "icmp_options" {
    for_each = tostring(each.value.protocol) == tostring(local.icmp_protocol) ? [1] : []
    content {
      type = 3
      code = 4
    }
  }

  lifecycle {
    precondition {
      condition = tostring(each.value.protocol) == tostring(local.icmp_protocol) || contains(keys(each.value), "port") || (
        contains(keys(each.value), "port_min") && contains(keys(each.value), "port_max")
      )
      error_message = "TCP/UDP rule must contain a port or port range: '${each.key}'"
    }

    precondition {
      condition = (
        tostring(each.value.protocol) == tostring(local.icmp_protocol)
        || can(tonumber(each.value.port))
        || (can(tonumber(each.value.port_min)) && can(tonumber(each.value.port_max)))
      )

      error_message = "TCP/UDP ports must be numeric: '${each.key}'"
    }

    precondition {
      condition     = each.value.direction == "EGRESS" || coalesce(each.value.source, "none") != "none"
      error_message = "Ingress rule must have a source: '${each.key}'"
    }

    precondition {
      condition     = each.value.direction == "INGRESS" || coalesce(each.value.destination, "none") != "none"
      error_message = "Egress rule must have a destination: '${each.key}'"
    }
  }
}