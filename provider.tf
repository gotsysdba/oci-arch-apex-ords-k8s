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

data "oci_identity_region_subscriptions" "home_region" {
  tenancy_id = var.ociTenancyOcid
  filter {
    name   = "is_home_region"
    values = ["true"]
  }
}

locals {
  home_region = data.oci_identity_region_subscriptions.home_region.region_subscriptions[0].region_name
  user_ocid   = var.ociUserOcid != "" ? var.ociUserOcid : var.current_user_ocid
}

provider "oci" {
  region           = var.ociRegionIdentifier
  tenancy_ocid     = var.ociTenancyOcid
  user_ocid        = local.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  private_key      = var.private_key
}

provider "oci" {
  region           = local.home_region
  tenancy_ocid     = var.ociTenancyOcid
  user_ocid        = local.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  private_key      = var.private_key
  alias            = "home_region"
}
