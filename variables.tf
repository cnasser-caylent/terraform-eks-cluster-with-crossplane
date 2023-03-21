variable "vpc_id" {
  type = string
}

variable "subnets_ids" {
  type    = list(string)
}

variable "configmap_auth_roles" {
  type = list(object({
    rolearn = string
    username = string
    groups = list(string)
  }))
  default = []
}

variable "aws_account_id" {
  type = string
}

variable "tags" {
  type = map
  default 	= {}
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint_public_access" {
  type = bool
  default = false
}

variable "cluster_version" {
  type = string
  default = "1.25"
}
