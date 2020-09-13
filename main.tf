data "aws_secretsmanager_secret" "cloud_manager_group_id" {
  name = var.cloud_manager_group_id_secret_name
}

data "aws_secretsmanager_secret_version" "cloud_manager_group_id_secret" {
  secret_id = data.aws_secretsmanager_secret.cloud_manager_group_id.id
}

data "aws_secretsmanager_secret" "cloud_manager_api_key" {
  name = var.cloud_manager_api_key_secret_name
}

data "aws_secretsmanager_secret_version" "cloud_manager_api_key_secret" {
  secret_id = data.aws_secretsmanager_secret.cloud_manager_api_key.id
}

# user_data.sh
data "template_file" "bootstrap" {
  template = file("${path.module}/files/bootstrap.sh")

  vars = {
    CLOUD_MANAGER_GROUP_ID = data.aws_secretsmanager_secret_version.cloud_manager_group_id_secret.secret_string
    CLOUD_MANAGER_API_KEY  = data.aws_secretsmanager_secret_version.cloud_manager_api_key_secret.secret_string
  }
}

# vpc data source
data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "mongodb" {
  name   = "ec2-${var.name}"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  tags = {
    Name          = "ec2-${var.name}"
    Cluster       = var.name
    InstanceGroup = var.name
    Terraform     = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "mongodb" {
  name        = "MongoDBRole-${var.name}"
  description = "Managed by Terraform"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "mongodb" {
  count      = length(var.associate_iam_policies)
  role       = aws_iam_role.mongodb.name
  policy_arn = element(var.associate_iam_policies, count.index)
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "MongoDBInstanceProfile-${var.name}"
  path = "/"
  role = aws_iam_role.mongodb.name
}

resource "aws_launch_configuration" "mongodb" {
  image_id             = var.ami
  instance_type        = var.instance_type
  key_name             = var.key_name
  user_data            = data.template_file.bootstrap.rendered
  iam_instance_profile = aws_iam_instance_profile.mongodb.name
  security_groups             = concat([aws_security_group.mongodb.id], var.security_group_ids)
  associate_public_ip_address = var.associate_public_ip_address
  ebs_optimized               = var.ebs_optimized

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp2"
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = var.datadir_volume_size
    volume_type           = "gp2"
    delete_on_termination = var.datadir_volume_delete_on_termination
  }

  lifecycle {
    ignore_changes = [key_name]
  }
}

resource "aws_lb" "mongodb" {
  name               = "NLB-${var.name}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.lb_subnet_ids

  tags = {
    Name          = var.name
    Cluster       = var.name
    InstanceGroup = var.name
    Terraform     = true
  }
}

resource "aws_lb_target_group" "mongodb" {
  name_prefix = "nlb"
  port        = 27017
  protocol    = "TCP"
  vpc_id      = var.vpc_id

  tags = {
    Cluster       = var.name
    InstanceGroup = var.name
    Terraform     = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "mongodb" {
  load_balancer_arn = aws_lb.mongodb.arn
  port              = 27017
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.mongodb.arn
    type             = "forward"
  }

  depends_on = [aws_lb.mongodb]
}

resource "aws_autoscaling_group" "mongo" {
  count                     = var.pool_size
  name                      = "mongo${count.index + 1}-${var.name}"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = aws_launch_configuration.mongodb.id
  vpc_zone_identifier = [element(var.ec2_subnet_ids, count.index)]
  target_group_arns   = [aws_lb_target_group.mongodb.arn]

  tags = concat(
    [
      {
        "key"                 = "Name"
        "value"               = "EC2-${var.name}"
        "propagate_at_launch" = true
      },
      {
        "key"                 = "Cluster"
        "value"               = var.name
        "propagate_at_launch" = true
      },
      {
        "key"                 = "Terraform"
        "value"               = true
        "propagate_at_launch" = true
      },
    ],
  )
}
