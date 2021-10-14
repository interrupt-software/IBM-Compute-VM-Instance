terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.12.0"
    }
  }
}

provider "ibm" {
  region = "ca-tor"
}

resource "ibm_is_vpc" "interrupt_vpc" {
  name = "interrupt-vpc"
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
}

resource "ibm_compute_ssh_key" "interrupt_ssh_key" {
  label      = "interrupt-software"
  notes      = "interrupt_ssh_key_notes"
  public_key = tls_private_key.main.public_key_openssh
}

resource "ibm_compute_vm_instance" "poc_test" {
  hostname          = "host-b.example.com"
  domain            = "example.com"
  ssh_key_ids       = [ibm_compute_ssh_key.interrupt_ssh_key.id]
  os_reference_code = "UBUNTU_18_64"
  datacenter        = "tor01"
  network_speed     = 10
  cores             = 1
  memory            = 1024
}

data "ibm_compute_vm_instance" "poc_test" {
  hostname    = ibm_compute_vm_instance.poc_test.hostname
  domain      = ibm_compute_vm_instance.poc_test.domain
  most_recent = true
}

resource "null_resource" "configure-nginx" {
  depends_on = [
    ibm_compute_vm_instance.poc_test
  ]

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.main.private_key_pem}\" > private.key"
  }

  provisioner "local-exec" {
    command = "chmod 600 private.key"
  }

  provisioner "file" {
    source      = "nginx.bash"
    destination = "/home/ubuntu/nginx.bash"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("private.key")
      host        = ibm_compute_vm_instance.poc_test.ipv4_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/nginx.bash",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("private.key")
      host        = ibm_compute_vm_instance.poc_test.ipv4_address
    }
  }
}

output "ibm_compute_vm_instance" {
  value = data.ibm_compute_vm_instance.poc_test
}

output "ibm_compute_vm_ssh" {
  value = "ssh -i private.key ubuntu@${data.ibm_compute_vm_instance.poc_test.ipv4_address}"
}

output "ibm_compute_vm_url" {
  value = "http://${data.ibm_compute_vm_instance.poc_test.ipv4_address}"
}