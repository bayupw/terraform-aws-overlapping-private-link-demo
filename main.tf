data "aws_region" "current" {}

# Create 3 digit random string
resource "random_string" "this" {
  length  = 3
  number  = true
  special = false
  upper   = false
}

# Create VPCs, subnets, route tables
module "vpcs" {
  for_each = var.vpcs

  source               = "terraform-aws-modules/vpc/aws"
  version              = "~> 3.0"
  name                 = "${each.value.name}-${random_string.this.id}"
  cidr                 = each.value.cidr
  azs                  = each.value.azs
  public_subnets       = each.value.public_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "PrivateLinkDemo"
  }
}

# Create IAM role and IAM instance profile for SSM
module "ssm_instance_profile" {
  source  = "bayupw/ssm-instance-profile/aws"
  version = "1.0.0"
}

# VPC-A Web Server EC2 instance in VPC-B
module "web_server" {
  source  = "bayupw/amazon-linux-2/aws"
  version = "1.0.0"

  random_suffix                  = false
  instance_hostname              = local.webserver_hostname
  vpc_id                         = module.vpcs["vpc_a"].vpc_id
  subnet_id                      = module.vpcs["vpc_a"].public_subnets[0]
  private_ip                     = cidrhost(module.vpcs["vpc_a"].public_subnets_cidr_blocks[0], 11)
  iam_instance_profile           = module.ssm_instance_profile.aws_iam_instance_profile
  associate_public_ip_address    = true
  enable_password_authentication = true
  random_password                = false
  instance_username              = var.username
  instance_password              = var.password
  key_name                       = var.key_name

  depends_on = [module.vpcs, module.ssm_instance_profile]
}

# Create NLB in VPC-B
module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name               = local.nlb_name
  load_balancer_type = "network"
  vpc_id             = module.vpcs["vpc_a"].vpc_id
  subnets            = [module.vpcs["vpc_a"].public_subnets[0]]

  target_groups = [
    {
      name_prefix      = "wnlb-"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
      targets = [
        {
          target_id = module.web_server.aws_instance.id
          port      = 80
        }
      ]
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    }
  ]

  tags = {
    Name = "nlb"
  }

  depends_on = [module.web_server]
}

# VPC-B Client EC2 instance in VPC-B
module "client" {
  source  = "bayupw/amazon-linux-2/aws"
  version = "1.0.0"

  random_suffix                  = false
  instance_hostname              = local.client_hostname
  vpc_id                         = module.vpcs["vpc_b"].vpc_id
  subnet_id                      = module.vpcs["vpc_b"].public_subnets[0]
  private_ip                     = cidrhost(module.vpcs["vpc_b"].public_subnets_cidr_blocks[0], 11)
  iam_instance_profile           = module.ssm_instance_profile.aws_iam_instance_profile
  associate_public_ip_address    = true
  enable_password_authentication = true
  random_password                = false
  instance_username              = var.username
  instance_password              = var.password
  key_name                       = var.key_name

  depends_on = [module.vpcs, module.ssm_instance_profile]
}

data "aws_caller_identity" "current" {}

# Create VPC Endpoint Services of NLB  
resource "aws_vpc_endpoint_service" "web_ep_svc" {
  acceptance_required        = false
  network_load_balancer_arns = [module.nlb.lb_arn]
  allowed_principals         = [data.aws_caller_identity.current.arn]

  tags = {
    Name        = local.webepsvc_name
    Environment = "PrivateLinkDemo"
  }

  depends_on = [module.nlb]
}

# Create Security Group for VPC Endpoint Web in VPC-B
resource "aws_security_group" "web_endpoint_sg" {
  name        = local.webepsg_name
  description = "Allow all traffic to web-vpc-endpoint"
  vpc_id      = module.vpcs["vpc_b"].vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = module.client.aws_instance.vpc_security_group_ids
  }

  tags = {
    Name        = local.webepsg_name
    Environment = "PrivateLinkDemo"
  }

  depends_on = [module.vpcs]
}

# Create VPC Endpoint Web in VPC-B
resource "aws_vpc_endpoint" "web_ep" {
  service_name       = aws_vpc_endpoint_service.web_ep_svc.service_name
  subnet_ids         = [module.vpcs["vpc_b"].public_subnets[0]]
  vpc_endpoint_type  = aws_vpc_endpoint_service.web_ep_svc.service_type
  vpc_id             = module.vpcs["vpc_b"].vpc_id
  security_group_ids = [aws_security_group.web_endpoint_sg.id]

  tags = {
    Name        = local.webep_name
    Environment = "PrivateLinkDemo"
  }

  depends_on = [aws_vpc_endpoint_service.web_ep_svc, aws_security_group.web_endpoint_sg]
}

# Web NLB ENI object in VPC-A
data "aws_network_interface" "nlb_eni" {
  filter {
    name   = "description"
    values = ["ELB ${module.nlb.lb_arn_suffix}"]
  }

  depends_on = [module.nlb]
}

# Web VPC Endpoint ENI object in VPC-B
data "aws_network_interface" "web_ep_eni" {
  id = one(aws_vpc_endpoint.web_ep.network_interface_ids)

  depends_on = [aws_vpc_endpoint.web_ep]
}