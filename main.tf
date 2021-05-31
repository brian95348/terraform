provider "aws" {
    region = "us-east-1"
}

variable "AZ1" {}
variable "AZ2" {}
variable "vpc_cidr_block" {}
variable "subnet_cidr_block_1" {}
variable "subnet_cidr_block_2" {}
variable "stage" {}
variable "public_key_path" {}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block
  tags       = {
    Name = "${var.stage}-vpc"
  }
}

resource "aws_subnet" "pub_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_cidr_block_1
  availability_zone = var.AZ1
  tags = {
    Name = "${var.stage}-pub-subnet-1"
  }
}

resource "aws_subnet" "pub_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_cidr_block_2
  availability_zone = var.AZ2
  tags = {
    Name = "${var.stage}-pub-subnet-2"
  }
}

resource "aws_internet_gateway" "my-igw" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
    Name = "${var.stage}-igw"
  }
}

resource "aws_route_table" "my-rt" {
    vpc_id = aws_vpc.my_vpc.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my-igw.id
    }

    tags = {
    Name = "${var.stage}-rt"
  }
}

resource "aws_route_table_association" "my-rt-assoc" {
    subnet_id = aws_subnet.pub_subnet.id
    route_table_id = aws_route_table.my-rt.id
}

resource "aws_security_group" "my-sg" {
    name = "my-sg"
    vpc_id = aws_vpc.my_vpc.id
    ingress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 22
      protocol = "tcp"
      to_port = 22
    }

    ingress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 80
      protocol = "tcp"
      to_port = 80
    } 

    egress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 0
      protocol = "-1"
      to_port = 0
      prefix_list_ids = []
    } 

    tags = {
    Name = "${var.stage}-sg"
  }
}

data "aws_ami" "latest-ami-image" {
    most_recent = true
    owners = [ "amazon" ]
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }

    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }
}

resource "aws_key_pair" "my-key-pair" {
    key_name = "lin-svr-key"
    public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "jenkins-svr" {
    ami = data.aws_ami.latest-ami-image.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.pub_subnet.id
    vpc_security_group_ids = [ aws_security_group.my-sg.id ]
    availability_zone = var.AZ
    associate_public_ip_address = true
    key_name = aws_key_pair.my-key-pair.key_name
    user_data = <<EOF
                    #!/bin/bash
                    sudo yum -y update && sudo yum install -y jenkins
                    sudo systemctl start jenkins
                EOF
    tags = {
    Name = "${var.stage}-jenkins-server"
  }
}

resource "aws_instance" "ansible-svr" {
    ami = data.aws_ami.latest-ami-image.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.pub_subnet.id
    vpc_security_group_ids = [ aws_security_group.my-sg.id ]
    availability_zone = var.AZ
    associate_public_ip_address = true
    key_name = aws_key_pair.my-key-pair.key_name
    user_data = <<EOF
                    #!/bin/bash
                    ssh-keygen -t rsa
                    sudo chmod 400 ~/.ssh/id_rsa
                    sudo yum -y update && sudo yum install -y ansible
                    sudo systemctl start ansible
                EOF
    tags = {
    Name = "${var.stage}-ansible-server"
  }
}

resource "aws_instance" "kops-svr" {
    ami = data.aws_ami.latest-ami-image.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.pub_subnet.id
    vpc_security_group_ids = [ aws_security_group.my-sg.id ]
    availability_zone = var.AZ
    associate_public_ip_address = true
    key_name = aws_key_pair.my-key-pair.key_name
    user_data = file("kops.sh")
    tags = {
    Name = "${var.stage}-kops-server"
  }
}

