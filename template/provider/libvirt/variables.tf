variable "libvirt_uri" {
  description = "Libvirt connection URI"
  default = "{{config.get_value('libvirt', 'libvirt_uri', 'qemu:///system')}}"
}

variable "storage_pool" {
  description = "Storage pool to use for VM disks"
  default = "{{config.get_value('libvirt', 'storage_pool', 'default')}}"
}

variable "network_name" {
  description = "Network name for VMs"
  default = "{{config.get_value('libvirt', 'network_name', 'goad-network')}}"
}

variable "network_mode" {
  description = "Network mode (bridge, nat, etc)"
  default = "{{config.get_value('libvirt', 'network_mode', 'bridge')}}"
}

variable "network_bridge" {
  description = "Bridge interface for network (when using bridge mode)"
  default = "{{config.get_value('libvirt', 'network_bridge', 'virbr0')}}"
}

# Base VM template paths
# You can override these paths in globalsettings.ini under [libvirt_templates] section
# Or place your Windows qcow2 images in any of the searched locations
variable "vm_template_path" {
  type = map(string)
  description = "Paths to VM template images. Override in globalsettings.ini [libvirt_templates] section."
  
  default = {
    "WinServer2019_x64"  = "{{config.get_value('libvirt_templates', 'winserver2019_x64', '/var/lib/libvirt/images/WinServer2019_x64.qcow2')}}"
    "WinServer2016_x64"  = "{{config.get_value('libvirt_templates', 'winserver2016_x64', '/var/lib/libvirt/images/WinServer2016_x64.qcow2')}}"
    "Windows10_22h2_x64" = "{{config.get_value('libvirt_templates', 'windows10_22h2_x64', '/var/lib/libvirt/images/Windows10_22h2_x64.qcow2')}}"
  }
}

# Alternative paths to check for VM images (in order of preference)
variable "vm_template_search_paths" {
  type = list(string)
  description = "Directories to search for VM template images if not found at specified paths"
  
  default = [
    "/var/lib/libvirt/images",
    "~/Downloads", 
    "~/VMs",
    "/tmp",
    "."
  ]
}

variable "memory_mb" {
  description = "Default memory in MB"
  default = {{config.get_value('libvirt', 'default_memory', 2048)}}
}

variable "vcpu" {
  description = "Default number of vCPUs"
  default = {{config.get_value('libvirt', 'default_vcpu', 2)}}
}