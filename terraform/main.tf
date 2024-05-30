# https://help.aliyun.com/document_detail/95825.html?spm=a2c4g.95822.0.0.16636ef0JDPHuP
# https://registry.terraform.io/providers/aliyun/alicloud/latest/docs


# export ALICLOUD_ACCESS_KEY="xxxx"
# export ALICLOUD_SECRET_KEY="xxxx"
# export ALICLOUD_REGION="cn-guangzhou"

variable "terraform_ip" {
  type = string
  default = "202.105.67.55"
}

variable "region" {
  default = "cn-guangzhou"
}

variable "zone" {
  default = "cn-guangzhou-a"
}

variable "image_id" {
  default = "rockylinux_9_0_x64_20G_alibase_20230323.vhd"
}

resource "alicloud_vpc" "vpc" {
  vpc_name   = "vpc-devops"
  cidr_block = "10.0.0.0/8"
}

resource "alicloud_vswitch" "vswitch_guanghzou_a" {
  vswitch_name = "vswitch-guangzhou-a"
  vpc_id       = alicloud_vpc.vpc.id
  cidr_block   = "10.0.0.0/16"
  zone_id      = var.zone
}

resource "alicloud_security_group" "default" {
  name   = "devops"
  vpc_id = alicloud_vpc.vpc.id
}

# 获取本地的公网ip，并添加到许可： unset http_proxy && curl ifconfig.me
resource "alicloud_security_group_rule" "allow_terrafor_host" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = var.terraform_ip
}

resource "alicloud_security_group_rule" "allow_vpc" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = "10.0.0.0/8"
}
