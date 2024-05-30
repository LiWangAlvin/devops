# harbor, 使用4核2G抢占式实例
resource "alicloud_instance" "harbor" {
  instance_name              = "harbor"
  host_name                  = "harbor"
  availability_zone          = var.zone
  security_groups            = alicloud_security_group.default.*.id
  instance_type              = "ecs.e-c1m2.large"
  system_disk_category       = "cloud_essd_entry"
  system_disk_name           = "harbor-os-disk"
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

resource "alicloud_security_group_rule" "allow_harbor" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = alicloud_instance.harbor.public_ip
}

# self-signed cert
resource "tls_private_key" "harbor" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "harbor" {
  private_key_pem = tls_private_key.harbor.private_key_pem

   validity_period_hours = 87600

    allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  subject {
    common_name  = "harbor-self.com"
  }
}

resource "local_sensitive_file" "cert_key" {
  content  = tls_self_signed_cert.harbor.private_key_pem
  filename = "${path.module}/cert.key"
}

resource "local_file" "cert" {
  content  = tls_self_signed_cert.harbor.cert_pem
  filename = "${path.module}/cert"
}

resource "null_resource" "prepare_harbor" {
  triggers = {
    master = alicloud_instance.harbor.id
  }

  depends_on = [ alicloud_security_group_rule.allow_terrafor_host, tls_self_signed_cert.harbor ]

  provisioner "local-exec" {
    command = <<EOF
      ansible-playbook -i '${alicloud_instance.harbor.public_ip},' \
      --ssh-common-args='-o StrictHostKeyChecking=no' \
      -u root --private-key="~/.ssh/aliyun" ${path.module}/ansible/harbor.yml -e '{
        "hostname": "${alicloud_instance.harbor.public_ip}",
        "cert_file": "${abspath(path.module)}/cert",
        "cert_key_file": "${abspath(path.module)}/cert.key"
      }'
    EOF
  }
}

output "harbor_public_ip" {
  value = alicloud_instance.harbor.public_ip
}

output "harbor_private_ip" {
  value = alicloud_instance.harbor.primary_ip_address
}

output "harbor_endpoint" {
  value = "https://${alicloud_instance.harbor.public_ip}"
}