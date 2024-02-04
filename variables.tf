# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "tenancy_ocid" {
  description = "The Tenancy ID of the OCI Cloud Account in which to create the resources."
  type        = string
}

variable "compartment_ocid" {
  description = "The compartment in which to create OCI Resources."
  type        = string
}

variable "region" {
  description = "The OCI Region where resources will be created."
  type        = string
}

variable "user_ocid" {
  description = "The ID of the User that terraform will use to create the resources."
  type        = string
  default     = ""
}

variable "current_user_ocid" {
  description = "The ID of the user that terraform will use to create the resources. ORM compatible"
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "Fingerprint of the API private key to use with OCI API."
  type        = string
  default     = ""
}

variable "private_key" {
  description = "The contents of the private key file to use with OCI API. This takes precedence over private_key_path if both are specified in the provider."
  sensitive   = true
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "The path to the OCI API private key."
  type        = string
  default     = ""
}

variable "label_prefix" {
  description = "Alpha Numeric (less than 12 characters) string that will be prepended to all resources. Leave blank to auto-generate."
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^[a-zA-Z0-9]*$", var.label_prefix)) || length(var.label_prefix) < 12
    error_message = "Must be Alpha Numeric and less than 12 characters."
  }
}

// OKE Cluster
variable "oke_version" {
  description = "The version of Kubernetes to install into the cluster masters."
  type        = string
  default     = "1.28.2"
}

variable "oke_api_is_public" {
  type    = bool
  default = true
}

# This is a string and not a list to support ORM/MP input, it will be converted to a list in locals
variable "oke_api_endpoint_allowed_cidrs" {
  description = "Comma separated string of CIDR blocks from which the API Endpoint can be accessed."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(regex("$|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9])(,?)( ?)){1,}$", var.oke_api_endpoint_allowed_cidrs))
    error_message = "Must be a comma seperated string of valid CIDRs."
  }
}

variable "oke_worker_pool_size" {
  description = "Number of Workers in the default Node Pool."
  type        = number
  default     = 2
}

variable "oke_node_worker_shape" {
  description = "Choose the shape of the Node Pool Workers."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "oke_node_worker_ocpu" {
  description = "The initial number of OCPU for the Node Pool Workers."
  type        = number
  default     = 1
}

// LoadBalancer
variable "service_lb_is_public" {
  type    = bool
  default = true
}

variable "service_lb_ingress" {
  description = "Load Balancer Service Application."
  type        = string
  default     = "ingress-nginx"
}

variable "service_lb_min_shape" {
  description = "Bandwidth in Mbps that determines the min bandwidth (ingress plus egress) that the load balancer can achieve."
  type        = number
  default     = 10
}

variable "service_lb_max_shape" {
  description = "Bandwidth in Mbps that determines the max bandwidth (ingress plus egress) that the load balancer can achieve."
  type        = number
  default     = 10
}

variable "service_lb_allowed_cidrs" {
  description = "Comma separated string of CIDR blocks from which the Load Balancer can be accessed."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(regex("((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9])(,?)( ?)){1,}$", var.service_lb_allowed_cidrs))
    error_message = "Must be a comma seperated string of valid CIDRs."
  }
}

variable "service_lb_allowed_ports" {
  description = "Comma separated string of ports from which the Load Balancer will listen."
  type        = string
  default     = "80, 443"
  validation {
    condition     = can(regex("^(((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))(,?)( ?)){1,}$", var.service_lb_allowed_ports))
    error_message = "Must be a comma seperated string of valid ports."
  }
}

// Database
variable "adb_compute_model" {
  description = "Choose the Autonomous Database Compute Model."
  type        = string
  default     = "ECPU"
  validation {
    condition     = contains(["OCPU", "ECPU"], var.adb_compute_model)
    error_message = "Must be either OCPU or ECPU."
  }
}

variable "adb_networking" {
  description = "Choose the Autonomous Database Network Access."
  type        = string
  default     = "SECURE_ACCESS"
  validation {
    condition     = contains(["PRIVATE_ENDPOINT_ACCESS", "SECURE_ACCESS"], var.adb_networking)
    error_message = "Must be either PRIVATE_ENDPOINT_ACCESS or SECURE_ACCESS."
  }
}

variable "adb_ecpu_core_count" {
  description = "Choose how many ECPU cores will be elastically allocated."
  type        = number
  default     = 2
  validation {
    condition     = var.adb_ecpu_core_count >= 2
    error_message = "Must be equal or greater than 2."
  }
}

variable "adb_ocpu_core_count" {
  description = "Choose how many OCPU cores will be allocated."
  type        = number
  default     = 1
  validation {
    condition     = var.adb_ocpu_core_count >= 1
    error_message = "Must be equal or greater than 1."
  }
}

variable "adb_data_storage_size_in_gb" {
  description = "Choose ADB Database Data Storage Size in gigabytes."
  type        = number
  default     = 20
  validation {
    condition     = var.adb_data_storage_size_in_gb >= 20 && var.adb_data_storage_size_in_gb <= 393216
    error_message = "Must be equal or greater than 20 and equal or less than 393216."
  }
}

variable "adb_data_storage_size_in_tbs" {
  description = "Choose ADB Database Data Storage Size in terabytes."
  type        = number
  default     = 1
  validation {
    condition     = var.adb_data_storage_size_in_tbs >= 1 && var.adb_data_storage_size_in_tbs <= 384
    error_message = "Must be equal or greater than 1 and equal or less than 384."
  }
}

variable "adb_is_cpu_auto_scaling_enabled" {
  type    = bool
  default = false
}

variable "adb_is_storage_auto_scaling_enabled" {
  type    = bool
  default = false
}

variable "adb_license_model" {
  description = "Choose Autonomous Database license model."
  type        = string
  default     = "LICENSE_INCLUDED"
  validation {
    condition     = contains(["LICENSE_INCLUDED", "BRING_YOUR_OWN_LICENSE"], var.adb_license_model)
    error_message = "Must be either LICENSE_INCLUDED or BRING_YOUR_OWN_LICENSE."
  }
}

variable "adb_edition" {
  # Only Applicable when adb_license_model=BYOL
  description = "Oracle Database Edition that applies to the Autonomous databases (BYOL)."
  type        = string
  default     = "ENTERPRISE_EDITION"
  validation {
    condition     = contains(["", "ENTERPRISE_EDITION", "STANDARD_EDITION"], var.adb_edition)
    error_message = "Must be either ENTERPRISE_EDITION or STANDARD_EDITION."
  }
}

variable "adb_whitelist_cidrs" {
  # This is a string and not a list to support ORM/MP input, it will be converted to a list in locals
  description = "Comma separated string of CIDR blocks from which the ADB can be accessed."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(regex("$|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9])(,?)( ?)){1,}$", var.adb_whitelist_cidrs))
    error_message = "Must be a comma seperated string of valid CIDRs."
  }
}

variable "adb_bastion_cidrs" {
  # This is a string and not a list to support ORM/MP input, it will be converted to a list in locals
  description = "Comma separated string of CIDR blocks from which the ADB Bastion Service can be accessed."
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(regex("$|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]).(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9])(,?)( ?)){1,}$", var.adb_bastion_cidrs))
    error_message = "Must be a comma seperated string of valid CIDRs."
  }
}

variable "adb_create_bucket" {
  type    = bool
  default = false
}

// Miscellaneous
variable "orm_install" {
  description = "Provisioning via Oracle Resource Manager"
  type        = bool
  default     = false
}

variable "run_ansible" {
  description = "Run Ansible Configuration Management"
  type        = bool
  default     = true
}

#################################################
# module-network
#################################################
variable "byo_vcn" {
  description = "Use an existing VCN or create a new one?"
  type        = bool
  default     = false
}

variable "byo_vcn_ocid" {
  description = "The OCID of the BYO VCN resource"
  type        = string
  default     = ""
}

variable "byo_public_subnet_ocid" {
  description = "The OCID of the BYO Public Subnet resource"
  type        = string
  default     = ""
}

variable "byo_private_subnet_ocid" {
  description = "The OCID of the BYO Private Subnet resource"
  type        = string
  default     = ""
}

variable "worker_nsg_lockdown" {
  description = "Allow workers full access to internet?"
  type        = bool
  default     = false
}

variable "byo_auth_token" {
  description = "Bring Your Own Authorization Token"
  type        = string
  default     = ""
}