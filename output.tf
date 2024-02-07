# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "kubeconfig_cmd" {
  description = "Command to generate kubeconfig file"
  value = format(
    "oci ce cluster create-kubeconfig --cluster-id %s --region %s --token-version 2.0.0 --kube-endpoint %s --file $HOME/.kube/config",
    oci_containerengine_cluster.default_cluster.id,
    var.ociRegionIdentifier,
    oci_containerengine_cluster.default_cluster.endpoint_config[0].is_public_ip_enabled ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"
  )
}

//ADB
output "adb_name" {
  description = "Autonomous Database Name"
  value       = oci_database_autonomous_database.default_adb.db_name
}

output "adb_ip" {
  description = "Autonomous Database IP Address"
  value       = var.adb_networking == "PRIVATE_ENDPOINT_ACCESS" ? oci_database_autonomous_database.default_adb.private_endpoint_ip : "Secured Access"
}

output "adb_admin_password" {
  description = "Autonomous Database ADMIN Password"
  value       = oci_database_autonomous_database.default_adb.admin_password
  sensitive   = true
}

output "ords_uri" {
  description = "Public Access."
  value       = format("https://%s", oci_core_public_ip.service_lb[0].ip_address)
}