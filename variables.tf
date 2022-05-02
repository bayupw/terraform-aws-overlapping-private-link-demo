variable "vpcs" {
  description = "Maps of VPC attributes"
  type        = map(any)
  default = {
    vpc_a = {
      name           = "PrivateLink-Provider-VPC-A"
      cidr           = "10.0.0.0/16"
      azs            = ["ap-southeast-2a"]
      public_subnets = ["10.0.0.0/24"]
    }
    vpc_b = {
      name           = "PrivateLink-Consumer-VPC-B"
      cidr           = "10.0.0.0/16"
      azs            = ["ap-southeast-2a"]
      public_subnets = ["10.0.0.0/24"]
    }
  }
}

variable "username" {
  description = "EC2 instance username"
  type        = string
  default     = "ec2-user"
}

variable "password" {
  description = "EC2 instance password"
  type        = string
  default     = "Aviatrix123#"
}

variable "key_name" {
  description = "Existing EC2 Key Pair"
  type        = string
  default     = "ec2_keypair"
}

locals {
  client_hostname    = "privatelinkdemo-client-${random_string.this.id}"
  webserver_hostname = "privatelinkdemo-webserver-${random_string.this.id}"
  nlb_name           = "privatelinkdemo-nlb-${random_string.this.id}"
  webepsvc_name      = "web-endpoint-service-${random_string.this.id}"
  webepsg_name       = "web-endpoint-sg-${random_string.this.id}"
  webep_name         = "web-endpoint-service-${random_string.this.id}"
}