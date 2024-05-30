resource "alicloud_security_group_rule" "allow_jenkins" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = alicloud_instance.jenkins.public_ip
}

# Jenkins, 使用2核4G抢占式实例
resource "alicloud_instance" "jenkins" {
  instance_name              = "jenkins"
  host_name                  = "jenkins"
  availability_zone          = var.zone
  security_groups            = alicloud_security_group.default.*.id
  instance_type              = "ecs.e-c1m2.large"
  system_disk_category       = "cloud_essd_entry"
  system_disk_name           = "jenkins-os-disk"
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

resource "null_resource" "prepare_jenkins" {
  triggers = {
    master = alicloud_instance.jenkins.id
  }

  depends_on = [ alicloud_security_group_rule.allow_terrafor_host ]

  provisioner "local-exec" {
    command = <<EOF
      ansible-playbook -i '${alicloud_instance.jenkins.public_ip},' \
      --ssh-common-args='-o StrictHostKeyChecking=no' \
      -u root --private-key="~/.ssh/aliyun" ${path.module}/ansible/jenkins.yml -e '{
        "from_backup": true,
         "harbor_endpoint": "${alicloud_instance.harbor.public_ip}"
      }'
    EOF
  }
}

#  "harbor_endpoint": "${alicloud_instance.harbor.public_ip}"

output "jenkins_public_ip" {
  value = alicloud_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  value = alicloud_instance.jenkins.primary_ip_address
}

output "jenkins_endpoint" {
  value = "http://${alicloud_instance.jenkins.public_ip}:8080"
}