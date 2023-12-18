# Copyright © 2023, Oracle and/or its affiliates.
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "label_prefix" {
  type = string
}

variable "byo_vcn" {
  type = bool
}

variable "byo_vcn_ocid" {
  type    = string
  default = ""
}

variable "create_public_subnet" {
  type = bool
}

variable "byo_public_subnet_ocid" {
  type    = string
  default = ""
}

variable "create_private_subnet" {
  type = bool
}

variable "byo_private_subnet_ocid" {
  type    = string
  default = ""
}