variable "compartment_ocid" {}
variable "keyfile" {}
variable "userdata" {}
variable "image_ocid" {}
variable "workers_net" {}
variable "ads" {
  type=list(string)
  default = []
}