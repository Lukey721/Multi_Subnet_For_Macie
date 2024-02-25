#Author: Luke Connolly
#Student Number: X00218713
#Module: IT Infastructure

#notes: only deploying in one region currently 
#2.change example sub net

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "main_vpc"
  }
}

#AVAILABILITY ZONE 1
resource "aws_subnet" "first_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.CIDR_BLOCK_SUBNET[0]
  availability_zone = var.AVAILABILITY_ZONES[0]   #look to array for availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "first_subnet"
  }
}

#AVAILABILITY ZONE 2
resource "aws_subnet" "second_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.CIDR_BLOCK_SUBNET[1]
  availability_zone = var.AVAILABILITY_ZONES[1]  
  map_public_ip_on_launch = true
  tags = {
    Name = "second_subnet"
  }
}

#AVAILABILITY ZONE 3
resource "aws_subnet" "third_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.CIDR_BLOCK_SUBNET[2]
  availability_zone = var.AVAILABILITY_ZONES[2]
  map_public_ip_on_launch = true
  tags = {
    Name = "third_subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "i_gateway" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Internet_Gateway" #was prev "Internet_Gateway"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.i_gateway.id
  }

  tags = {
    Name = "Public_Route_Table" #was prev "PublicRouteTable"
  }
}

# resource "aws_instance" "government_cloud" {
#     ami = lookup(var.AMI, var.REGION)
#     instance_type = var.INSTANCE_TYPE
#     key_name = var.KEY_NAME
#     #count of how many ec2 to deploy 
#     count = 2
#     security_groups = [aws_security_group.allow_web.id]
#     subnet_id = aws_subnet.first_subnet.id  # add subnet to the instances
    
#     tags = {
#       Name = "GOV_EC2_NO_${count.index + 1}"
#     }
# }

# Associate the public subnet 1 with the public route table
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.first_subnet.id
  route_table_id = aws_route_table.public.id
}

# Associate the public subnet 2 with the public route table
resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.second_subnet.id
  route_table_id = aws_route_table.public.id
}

# Associate the public subnet 3 with the public route table
resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.third_subnet.id
  route_table_id = aws_route_table.public.id
}



resource "aws_security_group" "allow_web" {

    name = "Allow Web Traffic"
    description = "Allow Web Inbound"
    vpc_id = aws_vpc.main_vpc.id
  
  ingress {
    
    description = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = var.CIDR_BLOCK_ALL_IPV4
    
  }

  #ingress {
  #  description = "Allow HTTPs"
  #  from_port        = 443
  #  to_port          = 443
  #  protocol         = "tcp"
  #  cidr_blocks      = ["0.0.0.0/0"]
  #  
  #}

  ingress {
    description = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.CIDR_BLOCK_ALL_IPV4
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = var.CIDR_BLOCK_ALL_IPV4
    
  }

  tags = {
    Name = "Allow Web Traffic to VPC"
  }
}

#create load balancer
resource "aws_lb" "web-balancer" {
  name = "web-balancer"
  internal = false
  load_balancer_type = "application" #as web traffic choose between 3
  ip_address_type = "ipv4" #now changed
  security_groups = [ aws_security_group.allow_web.id ] #now changed
  subnets = [ aws_subnet.first_subnet.id, aws_subnet.second_subnet.id, aws_subnet.third_subnet.id ]

  tags = {
    Name = "web-balancer"
  }
}

#create target group for alb
resource "aws_lb_target_group" "web-balancer-target-gp" {

  name = "web-balancer-target-gp"
  target_type = "instance"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main_vpc.id

  
  #health_check {
  #  protocol = "HTTP"
  #  path = "/index.html"
  #  port = 80
  #}

  tags = {
    Name = "web-balancer-target-gp"
  }
  
}

#create ALB listener on port 80 and send traffic to target group

resource "aws_lb_listener" "web_balancer_listener" {
  load_balancer_arn = aws_lb.web-balancer.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web-balancer-target-gp.arn
  }
}

resource "aws_launch_template" "app_launch_template" {
   
   name = "app_launch_template"
   image_id = lookup(var.AMI, var.REGION)
   instance_type = var.INSTANCE_TYPE
   key_name = var.KEY_NAME

   vpc_security_group_ids = [aws_security_group.allow_web.id]

   tag_specifications {
     resource_type = "instance"

     tags = {
       Name = "gov-server"
     }
   }
    user_data = filebase64("script.sh")

    lifecycle {
      create_before_destroy = true
    }

}

#create auto scaling group
resource "aws_autoscaling_group" "web_auto_scaling" {
  name = "web_auto_scaling"
  desired_capacity = 3 # num of instances
  max_size = 5
  min_size = 2
  #health_check_type = "ELB"

  launch_template {
    id = aws_launch_template.app_launch_template.id
  }

  vpc_zone_identifier = [ aws_subnet.first_subnet.id, aws_subnet.second_subnet.id, aws_subnet.third_subnet.id]
  tag {
    key = "Name"
    value = "web_auto_scaling"
    propagate_at_launch = true

  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_attachment" "web_auto_scaling_attachment" {
  
 autoscaling_group_name = aws_autoscaling_group.web_auto_scaling.id
 lb_target_group_arn = aws_lb_target_group.web-balancer-target-gp.arn
}


#create a s3 bucket for aws macie example
resource "aws_s3_bucket" "gov_data_bucket" {
  bucket = var.bucketname
}

#who owns bucket
resource "aws_s3_bucket_ownership_controls" "gov_data_bucket_oc" {
  bucket = aws_s3_bucket.gov_data_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#block public access to my bucket
resource "aws_s3_bucket_public_access_block" "gov_data_bucket_block_access" {
  bucket = aws_s3_bucket.gov_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "gov_data_bucket_acl" {

  depends_on = [
    aws_s3_bucket_ownership_controls.gov_data_bucket_oc,
    aws_s3_bucket_public_access_block.gov_data_bucket_block_access,
  ]

  bucket = aws_s3_bucket.gov_data_bucket.id
  #can be read by the bucket owner
   acl    = "private"

}

#upload file to bucket with no sensitive data
resource "aws_s3_object" "data" {
  bucket = aws_s3_bucket.gov_data_bucket.id
  key = "data.txt"
  source = "data.txt"
  acl = "private"
}

#upload file to bucket with sensitive data 
resource "aws_s3_object" "sensitive" {
  bucket = aws_s3_bucket.gov_data_bucket.id
  key = "emp_details.csv"
  source = "emp_details.csv"
  acl = "private"
}




#References

#VPC https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#example-usage:~:text=a%20VPC%20resource.-,Example%20Usage,-Basic%20usage%3A

#increment count https://stackoverflow.com/questions/55509786/terraform-vm-name-prefix-auto-increment-modification#:~:text=name%20%3D%20%22%24%7Bvar.vm_name_prefix%7D%24%7Bcount.index%20%2B%201%7D%22

#security group https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#:~:text=this%20egress%20block%3A-,resource,-%22aws_security_group%22%20%22example

























