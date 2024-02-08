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
  tenancy_id = local.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = ["true"]
  }
}

locals {
  home_region = data.oci_identity_region_subscriptions.home_region.region_subscriptions[0].region_name
}

provider "oci" {
  region           = local.region
  tenancy_ocid     = local.tenancy_ocid
  user_ocid        = local.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.resPathUserPublicKey
  private_key      = var.resUserPublicKey
}

provider "oci" {
  region           = local.home_region
  tenancy_ocid     = local.tenancy_ocid
  user_ocid        = local.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.resPathUserPublicKey
  private_key      = var.resUserPublicKey
  alias            = "home_region"
}
