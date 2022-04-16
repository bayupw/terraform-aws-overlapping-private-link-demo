# Create VPCs, subnets, route tables
module "vpcs" {
  for_each = var.vpcs

  source               = "terraform-aws-modules/vpc/aws"
  version              = "~> 3.0"
  name                 = each.value.name
  cidr                 = each.value.cidr
  azs                  = each.value.azs
  public_subnets       = each.value.public_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "PrivateLink"
  }
}

# Create IAM role and IAM instance profile for SSM
module "ssm_instance_profile" {
  source  = "bayupw/ssm-instance-profile/aws"
  version = "1.0.0"
}

# VPC-A Client EC2 instance in VPC-A
module "client" {
  source  = "bayupw/amazon-linux-2/aws"
  version = "1.0.0"

  instance_hostname           = "privatelinkdemo-client"
  vpc_id                      = module.vpcs["vpc_a"].vpc_id
  subnet_id                   = module.vpcs["vpc_a"].public_subnets[0]
  associate_public_ip_address = true
  private_ip                  = cidrhost(module.vpcs["vpc_a"].public_subnets_cidr_blocks[0], 11)
  iam_instance_profile        = module.ssm_instance_profile.aws_iam_instance_profile

  depends_on = [module.ssm_instance_profile]
}

# VPC-B Web Server EC2 instance in VPC-B
module "web_server" {
  source  = "bayupw/amazon-linux-2/aws"
  version = "1.0.0"

  instance_hostname           = "privatelinkdemo-web-server"
  vpc_id                      = module.vpcs["vpc_b"].vpc_id
  subnet_id                   = module.vpcs["vpc_b"].public_subnets[0]
  associate_public_ip_address = true
  private_ip                  = cidrhost(module.vpcs["vpc_b"].public_subnets_cidr_blocks[0], 11)
  iam_instance_profile        = module.ssm_instance_profile.aws_iam_instance_profile

  depends_on = [module.ssm_instance_profile]
}

# Create NLB in VPC-B
module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name               = "nlb"
  load_balancer_type = "network"
  vpc_id             = module.vpcs["vpc_b"].vpc_id
  subnets            = [module.vpcs["vpc_b"].public_subnets[0]]

  target_groups = [
    {
      name_prefix      = "web-"
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

data "aws_caller_identity" "current" {}

# Create VPC Endpoint Services from NLB of VPC-B  
resource "aws_vpc_endpoint_service" "web_ep_svc" {
  acceptance_required        = false
  network_load_balancer_arns = [module.nlb.lb_arn]
  allowed_principals         = [data.aws_caller_identity.current.arn]

  tags = {
    Name = "web-endpoint-service"
  }

  depends_on = [module.nlb]
}

# Create Security Group for VPC Endpoint Web in VPC-A
resource "aws_security_group" "web_endpoint_sg" {
  name        = "web-endpoint-sg"
  description = "Allow all traffic to web-vpc-endpoint"
  vpc_id      = module.vpcs["vpc_a"].vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = module.client.aws_instance.vpc_security_group_ids
  }

  tags = {
    Name = "web-endpoint-sg"
  }
}

# Create VPC Endpoint Web in VPC-A
resource "aws_vpc_endpoint" "web_ep" {
  service_name       = aws_vpc_endpoint_service.web_ep_svc.service_name
  subnet_ids         = [module.vpcs["vpc_a"].public_subnets[0]]
  vpc_endpoint_type  = aws_vpc_endpoint_service.web_ep_svc.service_type
  vpc_id             = module.vpcs["vpc_a"].vpc_id
  security_group_ids = [aws_security_group.web_endpoint_sg.id]

  tags = {
    Name = "web-endpoint-service"
  }

  depends_on = [aws_vpc_endpoint_service.web_ep_svc, aws_security_group.web_endpoint_sg]
}

# Web VPC Endpoint ENI object in VPC-A
data "aws_network_interface" "web_ep_eni" {
  id = one(aws_vpc_endpoint.web_ep.network_interface_ids)

  depends_on = [aws_vpc_endpoint.web_ep]
}

# Web NLB ENI object in VPC-B
data "aws_network_interface" "nlb_eni" {
  filter {
    name   = "description"
    values = ["ELB ${module.nlb.lb_arn_suffix}"]
  }

  depends_on = [module.nlb]
}