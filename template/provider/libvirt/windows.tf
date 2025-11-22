variable "vm_config" {
  type = map(object({
    name               = string
    desc               = string
    cores              = number
    memory             = number
    clone              = string
    dns                = string
    ip                 = string
    gateway            = string
  }))

  default = {
    {{windows_vms}}
  }
}

# Create a network for the GOAD lab
resource "libvirt_network" "goad_network" {
  name      = var.network_name
  mode      = var.network_mode
  bridge    = var.network_bridge
  autostart = true
  
  # Define the network range
  addresses = ["{{ip_range}}.0/24"]
  
  # DHCP configuration (optional, we'll use static IPs)
  dhcp {
    enabled = false
  }
  
  # DNS configuration
  dns {
    enabled = true
    local_only = true
  }
}

# Create cloud-init disks for each VM
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each = var.vm_config

  name           = "${each.value.name}-cloudinit.iso"
  pool           = var.storage_pool
  
  network_config = templatefile("${path.module}/network_config.cfg.tpl", {
    ip      = split("/", each.value.ip)[0]
    netmask = cidrnetmask(each.value.ip)
    gateway = each.value.gateway
    dns     = each.value.dns
  })
}

# Create disk images for each VM
resource "libvirt_volume" "vm_disk" {
  for_each = var.vm_config

  name           = "${each.value.name}-disk.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.base_image[each.value.clone].id
  size           = 107374182400  # 100GB in bytes
  format         = "qcow2"
}

# Base template volumes
resource "libvirt_volume" "base_image" {
  for_each = var.vm_template_path

  name   = "${each.key}-base.qcow2"
  pool   = var.storage_pool
  source = each.value
  format = "qcow2"
}

# Create VMs
resource "libvirt_domain" "vm" {
  for_each = var.vm_config

  name   = each.value.name
  memory = each.value.memory
  vcpu   = each.value.cores

  # Use UEFI firmware for Windows
  firmware = "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
  nvram {
    file = "/var/lib/libvirt/qemu/nvram/${each.value.name}_VARS.fd"
    template = "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
  }

  # Disk configuration
  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
    scsi      = false
  }

  # Cloud-init disk
  disk {
    volume_id = libvirt_cloudinit_disk.commoninit[each.key].id
  }

  # Network interface
  network_interface {
    network_id     = libvirt_network.goad_network.id
    hostname       = each.value.name
    wait_for_lease = true
  }

  # Graphics and console
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  # CPU configuration
  cpu {
    mode = "host-passthrough"
  }

  # Enable QEMU guest agent
  qemu_agent = true

  # Boot configuration
  boot_device {
    dev = ["hd"]
  }

  # Autostart with libvirtd
  autostart = false

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      nvram,
    ]
  }
}