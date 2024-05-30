# Rancher, 使用2核4G抢占式实例
resource "alicloud_instance" "rancher" {
  instance_name              = "rancher"
  host_name                  = "rancher"
  availability_zone          = var.zone
  security_groups            = alicloud_security_group.default.*.id
  instance_type              = "ecs.e-c1m2.large"
  system_disk_category       = "cloud_essd_entry"
  system_disk_name           = "rancher-os-disk"
  system_disk_size           = 40
  image_id                   = var.image_id
  vswitch_id                 = alicloud_vswitch.vswitch_guanghzou_a.id
  internet_max_bandwidth_out = 10
  key_name                   = "liam"
  spot_strategy              = "SpotAsPriceGo"
  instance_charge_type       = "PostPaid"

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      user                = "root"
      host                = self.public_ip
      private_key         = file("~/.ssh/aliyun")
    }
    inline = ["echo 'I am ready!'"]
  }
}

resource "alicloud_security_group_rule" "allow_rancher" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = alicloud_instance.rancher.public_ip
}

resource "null_resource" "prepare_rancher" {
  triggers = {
    master = alicloud_instance.rancher.id
  }

  depends_on = [ alicloud_security_group_rule.allow_terrafor_host ]

  provisioner "local-exec" {
    command = <<EOF
      ansible-playbook -i '${alicloud_instance.rancher.public_ip},' \
      --ssh-common-args='-o StrictHostKeyChecking=no' \
       -u root --private-key="~/.ssh/aliyun" ${path.module}/ansible/rancher.yml
    EOF
  }
}

output "rancher_public_ip" {
  value = alicloud_instance.rancher.public_ip
}

output "rancher_private_ip" {
  value = alicloud_instance.rancher.primary_ip_address
}

output "rancher_endpoint" {
  value = "https://${alicloud_instance.rancher.public_ip}"
}