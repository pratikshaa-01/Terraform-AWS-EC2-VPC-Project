# Define input variables
variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# VPC Resource
resource "aws_vpc" "pratu-vpc" {
  cidr_block = var.cidr_block
}

# Subnets
resource "aws_subnet" "sub-1" {
  vpc_id                  = aws_vpc.pratu-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub-2" {
  vpc_id                  = aws_vpc.pratu-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.pratu-vpc.id
}

# Route Table
resource "aws_route_table" "pratu-rt" {
  vpc_id = aws_vpc.pratu-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Route Table Associations
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub-1.id
  route_table_id = aws_route_table.pratu-rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub-2.id
  route_table_id = aws_route_table.pratu-rt.id
}

# Security Group
resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "This security group is for the terraform project"
  vpc_id      = aws_vpc.pratu-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-sg"
  }
}

# Security Group Ingress Rules
resource "aws_security_group_rule" "allow_http_ipv4" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.my-sg.id
}

resource "aws_security_group_rule" "allow_ssh_ipv4" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.my-sg.id
}

# S3 Bucket
resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "pratiksha-terraform-project"

  tags = {
    Name        = "My_s3_bucket"
    Environment = "Test"
  }
}

# EC2 Instances
resource "aws_instance" "web1" {
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.sub-1.id
  availability_zone      = "ap-south-1a"
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  user_data              = base64encode(file("${path.module}/userdata1.sh"))
  tags = {
    Name = "webserver1"
  }
}

resource "aws_instance" "web2" {
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.sub-2.id
  availability_zone      = "ap-south-1b"
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  user_data              = base64encode(file("${path.module}/userdata2.sh"))
  tags = {
    Name = "webserver2"
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my-sg.id]
  subnets            = [aws_subnet.sub-1.id, aws_subnet.sub-2.id]

  tags = {
    Name = "web-lb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "my-tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.pratu-vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# ALB Target Group Attachments
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "my-listner" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.my-tg.arn
    type             = "forward"
  }
}

# Output
output "loadbalancerdns" {
  value = aws_lb.my_alb.dns_name
}
