variable "vpcs" {
  description = "Maps of VPCs' attributes"
  type        = map(any)
  default = {
    vpc_a = {
      name           = "PrivateLink-VPC-A"
      cidr           = "10.0.0.0/16"
      azs            = ["ap-southeast-2a"]
      public_subnets = ["10.0.0.0/24"]
    }
    vpc_b = {
      name           = "PrivateLink-VPC-B"
      cidr           = "10.0.0.0/16"
      azs            = ["ap-southeast-2a"]
      public_subnets = ["10.0.0.0/24"]
    }
  }
}