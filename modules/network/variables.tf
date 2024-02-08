# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "label_prefix" {
  type = string
}

variable "vcn_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "byo_vcn" {
  type = bool
}

variable "byo_vcn_ocid" {
  type    = string
  default = ""
}

variable "byo_public_subnet_ocid" {
  type    = string
  default = ""
}

variable "byo_private_subnet_ocid" {
  type    = string
  default = ""
}