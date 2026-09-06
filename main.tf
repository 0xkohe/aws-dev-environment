data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "existing" {
  id = var.subnet_id
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name}-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "dev" {
  name = var.name
  role = aws_iam_role.ssm.name
}

resource "aws_security_group" "dev" {
  name        = var.name
  description = "Development host: outbound internet, no inbound ports; SSH through SSM"
  vpc_id      = data.aws_vpc.existing.id
  ingress     = []
  egress {
    description = "Development tools and SSM outbound connectivity"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = var.name }
}

resource "aws_key_pair" "dev" {
  key_name   = var.name
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "aws_instance" "dev" {
  ami                                  = var.ami_id
  instance_type                        = var.instance_type
  subnet_id                            = data.aws_subnet.existing.id
  associate_public_ip_address          = true
  vpc_security_group_ids               = [aws_security_group.dev.id]
  iam_instance_profile                 = aws_iam_instance_profile.dev.name
  key_name                             = aws_key_pair.dev.key_name
  disable_api_termination              = true
  instance_initiated_shutdown_behavior = "stop"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = false
    tags = {
      Name      = "${var.name}-root"
      Project   = var.name
      ManagedBy = "Terraform"
    }
  }

  user_data = join("\n", ["#cloud-config", yamlencode({
    package_update = true
    packages       = ["git", "gh", "tmux", "build-essential", "python3", "python3-venv", "unzip", "curl", "ca-certificates", "gnupg", "jq", "ripgrep"]
    write_files = [{
      path        = "/usr/local/sbin/asobi-bootstrap"
      owner       = "root:root"
      permissions = "0755"
      content     = file("${path.module}/cloud-init/bootstrap.sh")
    }]
    runcmd = [["bash", "/usr/local/sbin/asobi-bootstrap"]]
  })])

  depends_on = [aws_iam_role_policy_attachment.ssm]
  tags       = { Name = var.name }

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = data.aws_subnet.existing.vpc_id == data.aws_vpc.existing.id
      error_message = "The selected subnet must belong to the configured VPC."
    }
  }
}
