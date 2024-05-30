
# 一台master，2台worker,会被rancher用来创建K8s集群
# K8s, 使用2核4G抢占式实例
resource "alicloud_instance" "master" {
  instance_name              = "master"
  host_name                  = "master"
  availability_zone          = var.zone
  security_groups            = alicloud_security_group.default.*.id
  instance_type              = "ecs.e-c1m2.large"
  system_disk_category       = "cloud_essd_entry"
  system_disk_name           = "k8s-os-disk"
  system_disk_size           = 40
  image_id                   = var.image_id
  vswitch_id                 = alicloud_vswitch.vswitch_guanghzou_a.id
  internet_max_bandwidth_out = 10
  key_name                   = "liam"
  spot_strategy              = "SpotAsPriceGo"
  instance_charge_type       = "PostPaid"
}

output "master_public_ip" {
  value = alicloud_instance.master.public_ip
}

output "master_private_ip" {
  value = alicloud_instance.master.primary_ip_address
}

resource "alicloud_instance" "worker" {
  count = 2
  instance_name              = "worker-${count.index}"
  host_name                  = "worker-${count.index}"
  availability_zone          = var.zone
  security_groups            = alicloud_security_group.default.*.id
  instance_type              = "ecs.e-c1m2.large"
  system_disk_category       = "cloud_essd_entry"
  system_disk_name           = "k8s-os-disk"
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


resource "alicloud_security_group_rule" "allow_k8s_master" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = alicloud_instance.master.public_ip
}

resource "alicloud_security_group_rule" "allow_k8s_worker" {
  count = 2
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = alicloud_instance.worker[count.index].public_ip
}


output "worker_public_ips" {
  value = alicloud_instance.worker.*.public_ip
}

output "worker_private_ips" {
  value = alicloud_instance.worker.*.primary_ip_address
}

resource "null_resource" "prepare_k8s_node" {
  triggers = {
    master = alicloud_instance.master.id
    worker = join(",", alicloud_instance.worker.*.id)
  }

  depends_on = [ alicloud_security_group_rule.allow_terrafor_host ]

  provisioner "local-exec" {
    command = <<EOF
      ansible-playbook -i '${alicloud_instance.master.public_ip},${join(",", alicloud_instance.worker.*.public_ip)},' \
      --ssh-common-args='-o StrictHostKeyChecking=no' \
       -u root --private-key="~/.ssh/aliyun" ${path.module}/ansible/prepare-k8s.yml  -e '{
        "harbor_endpoint": "${alicloud_instance.harbor.public_ip}"
      }'
    EOF
  }
}