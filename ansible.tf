# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  # ansible_home is rewritten on a build
  ansible_home  = "${path.root}/ansible"
  orm_pe        = length(data.oci_resourcemanager_private_endpoint_reachable_ip.orm_pe_reachable_ip) == 1 ? data.oci_resourcemanager_private_endpoint_reachable_ip.orm_pe_reachable_ip[0].ip_address : "N/A"
  reserved_ip   = length(oci_core_public_ip.service_lb) == 1 ? oci_core_public_ip.service_lb[0].ip_address : "N/A"
  auth_token    = var.worker_nsg_lockdown ? var.byo_auth_token == "" ? var.byo_auth_token : oci_identity_auth_token.identity_auth_token[0].token : "N/A"
  registry_url  = lower(format("%s.ocir.io/%s", local.image_region, data.oci_objectstorage_namespace.objectstorage_namespace.namespace))
  registry_user = lower(format("%s/%s", data.oci_objectstorage_namespace.objectstorage_namespace.namespace, data.oci_identity_user.identity_user.name))
  registry_auth = base64encode(format("%s:%s", local.registry_user, local.auth_token))
}

########################################################################
# Ansible Infra Inventory Files -- !Looks Like Overkill! but...
# Method to the Madness - Templates are used to self-doco on-prem
# for MP/ORM files will be lost, need to write content again on destroy
########################################################################
// Common
data "template_file" "tf_vars_common_file" {
  template = file("${local.ansible_home}/roles/common/templates/vars.yaml")
  vars = {
    oci_tenancy_ocid     = local.tenancy_ocid
    oci_user_ocid        = local.user_ocid
    oci_fingerprint      = var.fingerprint
    oci_region           = local.region
    oci_compartment_ocid = local.compartment_ocid
  }
}
resource "local_sensitive_file" "tf_vars_common_file" {
  content         = data.template_file.tf_vars_common_file.rendered
  filename        = "${local.ansible_home}/roles/common/vars/main.yaml"
  file_permission = 0600
  lifecycle {
    create_before_destroy = true
  }
}

// OCI
data "template_file" "tf_vars_oci_file" {
  template = file("${local.ansible_home}/roles/oci/templates/vars.yaml")
  vars = {
    create_public        = var.service_lb_is_public
    pub_lb_ingress       = var.service_lb_ingress
    pub_lb_nsg           = try(oci_core_network_security_group.service_lb[0].id, "N/A")
    min_shape            = var.service_lb_min_shape
    max_shape            = var.service_lb_max_shape
    reserved_ip          = local.reserved_ip
    oke_cluster_id       = oci_containerengine_cluster.default_cluster.id
    oke_token_version    = "2.0.0"
    oke_private_endpoint = local.orm_pe
    bucket_namespace     = data.oci_objectstorage_namespace.objectstorage_namespace.namespace
    buckets              = join("\", \"", concat(try([oci_objectstorage_bucket.adb[0].name], [])))
  }
}
resource "local_sensitive_file" "tf_vars_oci_file" {
  content         = data.template_file.tf_vars_oci_file.rendered
  filename        = "${local.ansible_home}/roles/oci/vars/main.yaml"
  file_permission = 0600
  lifecycle {
    create_before_destroy = true
  }
}

// Database
data "template_file" "tf_vars_database_file" {
  template = file("${local.ansible_home}/roles/database/templates/vars.yaml")
  vars = {
    baas_db  = oci_database_autonomous_database.default_adb.db_name
    username = "ADMIN"
    password = oci_database_autonomous_database.default_adb.admin_password
    #password = sensitive(format("%s%s", random_password.adb_char.result, random_password.adb_rest.result))
    service  = format("%s_%s", oci_database_autonomous_database.default_adb.db_name, "TP")
    adb_ocid = oci_database_autonomous_database.default_adb.id
  }
}
resource "local_sensitive_file" "tf_vars_database_file" {
  content         = data.template_file.tf_vars_database_file.rendered
  filename        = "${local.ansible_home}/roles/database/vars/main.yaml"
  file_permission = 0600
}

// Image Container Registry
data "template_file" "tf_vars_registry_file" {
  template = file("${local.ansible_home}/roles/registry/templates/vars.yaml")
  vars = {
    registry_username       = local.registry_user
    registry_password       = local.auth_token
    registry_push_url       = format("%s/%s", local.registry_url, local.label_prefix)
    registry_pull_url       = format("%s/%s", local.registry_url, local.label_prefix)
    registry_push_auths_url = local.registry_url
    registry_pull_auths_url = local.registry_url
    registry_auths_auth     = local.registry_auth
  }
}

resource "local_sensitive_file" "tf_vars_registry_file" {
  content         = data.template_file.tf_vars_registry_file.rendered
  filename        = "${local.ansible_home}/roles/registry/vars/main.yaml"
  file_permission = 0600
}

########################################################################
# Ansible Provisioners - Apply
########################################################################
resource "null_resource" "ansible_images_build" {
  count = var.run_ansible ? 1 : 0
  provisioner "local-exec" {
    command = "ansible-playbook ${local.ansible_home}/images_build.yaml"
  }
  depends_on = [
    local_sensitive_file.tf_vars_common_file,
    local_sensitive_file.tf_vars_registry_file,
  ]
}

resource "null_resource" "ansible_k8s_apply" {
  count = var.run_ansible ? 1 : 0
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "ansible-playbook ${local.ansible_home}/k8s_apply.yaml -t full"
  }
  depends_on = [
    null_resource.ansible_images_build,
    local_sensitive_file.tf_vars_common_file,
    local_sensitive_file.tf_vars_database_file,
    local_sensitive_file.tf_vars_oci_file,
    oci_identity_policy.worker_node_policies,
    oci_containerengine_node_pool.default_node_pool_details
  ]
}

########################################################################
# Ansible Provisioners - Destroy
########################################################################
resource "null_resource" "ansible_k8s_destroy" {
  count = var.run_ansible ? 1 : 0
  triggers = {
    // DANGER! Avoid these file changing on stack modifications (e.g. BUCKETS!!)
    common_env = data.template_file.tf_vars_common_file.rendered
    oci_env    = data.template_file.tf_vars_oci_file.rendered
  }
  // Write Environment Files (Note: Paths will be rewritten by build.py)
  provisioner "local-exec" {
    when    = destroy
    command = "echo \"${self.triggers.common_env}\" > ansible/roles/common/vars/main.yaml"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "echo \"${self.triggers.oci_env}\" > ansible/roles/oci/vars/main.yaml"
  }

  // Peform Destroy
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "ansible-playbook ansible/k8s_destroy.yaml"
  }
  # Only execute when deleting OKE, and run before the bucket/OKE deletion
  # local_sensitive_file deps to avoid deletion of files created by self.triggers (on-prem)
  depends_on = [
    null_resource.ansible_images_build,
    local_sensitive_file.tf_vars_oci_file,
    local_sensitive_file.tf_vars_common_file,
    oci_resourcemanager_private_endpoint.orm_pe,
    oci_identity_policy.worker_node_policies,
    oci_containerengine_node_pool.default_node_pool_details,
    module.network,
  ]
}
