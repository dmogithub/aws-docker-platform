variable "region" {
  default = "eu-central-1"
}
variable "AmiLinux" {
  type = "map"
  default = {
    us-east-1 = "ami-d74be5b8"
  description = "I you can add all the regions that you need"
}
/*
variable "aws_access_key" {
  default = "xxxxx"
  description = "the user aws access key"
}

variable "aws_secret_key" {
  default = "xxxx"
  description = "the user aws secret key"
}
*/
variable "credentialsfile" {
  default = "/Users/giuseppe/.aws/credentials" #replace your home directory
  description = "where your access and secret_key are stored, you create the file when you run the aws config"
}

variable "vpc-fullcidr" {
    default = "172.28.0.0/16"
  description = "the vpc cdir"
}
variable "Subnet-Public-AzA-CIDR" {
  default = "172.28.0.0/24"
  description = "the cidr of the subnet"
}
variable "Subnet-Private-AzA-CIDR" {
  default = "172.28.3.0/24"
  description = "the cidr of the subnet"
}
variable "key_name" {
  default = "awspoc"
  description = "the ssh key to use in the EC2 machines"
}

variable "DnsZoneName" {
  default = "linuxacademy.internal"
  description = "the internal dns name"
}
