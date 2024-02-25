variable "AMI" {
  type = map(string)
  default = {
    us-east-1 = "ami-0e731c8a588258d0d"
    #add multi region availability

  }
}

variable "REGION" {
  default = "us-east-1"
 
}

variable "INSTANCE_TYPE" {
  default = "t2.micro"
}

variable "KEY_NAME" {
  default = "vockey"
}

variable "CIDR_BLOCK_SUBNET" {
  default = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
}

variable "CIDR_BLOCK_ALL_IPV4" {
  default = ["0.0.0.0/0"]
}

variable "AVAILABILITY_ZONES" {
  default = ["us-east-1a","us-east-1b","us-east-1c"]
}

variable "COUNTER" {
  default = [0]
}

variable "bucketname" {
  default = "gov-terraform-macie-20242024"
}