from goad.provider.terraform.terraform import TerraformProvider
from goad.utils import *
from goad.log import Log

try:
    import libvirt
    LIBVIRT_AVAILABLE = True
except ImportError:
    LIBVIRT_AVAILABLE = False
    Log.warning("libvirt-python not installed. Install with: pip install libvirt-python")


class LibvirtProvider(TerraformProvider):
    provider_name = "libvirt"
    default_provisioner = PROVISIONING_LOCAL
    allowed_provisioners = [PROVISIONING_LOCAL, PROVISIONING_RUNNER]

    def __init__(self, lab_name, config):
        super().__init__(lab_name)
        self.libvirt_uri = config.get_value('libvirt', 'libvirt_uri', 'qemu:///system')
        self.storage_pool = config.get_value('libvirt', 'storage_pool', 'default')
        self.network_name = config.get_value('libvirt', 'network_name', 'goad-network')

    def _get_libvirt_connection(self):
        """Get libvirt connection for status checks"""
        if not LIBVIRT_AVAILABLE:
            Log.error("libvirt-python not available")
            return None
        
        try:
            conn = libvirt.open(self.libvirt_uri)
            return conn
        except Exception as e:
            Log.error(f"Failed to connect to libvirt: {e}")
            return None

    def check(self):
        """Check if libvirt provider requirements are met"""
        checks = [
            self.command.check_terraform(),
            self.command.check_rsync()
        ]
        
        # Check libvirt connection
        if LIBVIRT_AVAILABLE:
            conn = self._get_libvirt_connection()
            if conn is not None:
                Log.info("✓ Libvirt connection successful")
                conn.close()
                checks.append(True)
            else:
                Log.error("✗ Libvirt connection failed")
                checks.append(False)
        else:
            Log.error("✗ libvirt-python not installed")
            checks.append(False)
        
        # Check for required tools
        import shutil
        if not shutil.which('mkisofs') and not shutil.which('genisoimage'):
            Log.error("✗ mkisofs/genisoimage not found. Install with: sudo pacman -S cdrtools")
            checks.append(False)
        else:
            Log.info("✓ ISO creation tools available")
            checks.append(True)
        
        # Check for Windows VM templates
        self._check_vm_templates()
            
        return all(checks)
    
    def _check_vm_templates(self):
        """Check for Windows VM template availability"""
        import os
        
        required_templates = [
            "WinServer2019_x64.qcow2"  # Most GOAD labs only need Windows Server 2019
        ]
        
        optional_templates = [
            "WinServer2016_x64.qcow2",  # Only needed for specific GOAD configurations
            "Windows10_22h2_x64.qcow2"  # Only needed for MINILAB workstation (WS01)
        ]
        
        search_paths = [
            "/var/lib/libvirt/images",
            os.path.expanduser("~/Downloads"),
            os.path.expanduser("~/VMs"),
            "/tmp",
            "."
        ]
        
        missing_required = []
        missing_optional = []
        found_templates = []
        
        # Check required templates
        for template in required_templates:
            found = False
            for search_path in search_paths:
                full_path = os.path.join(search_path, template)
                if os.path.exists(full_path):
                    found_templates.append(f"✓ {template} ({full_path})")
                    found = True
                    break
            
            if not found:
                missing_required.append(template)
        
        # Check optional templates
        for template in optional_templates:
            found = False
            for search_path in search_paths:
                full_path = os.path.join(search_path, template)
                if os.path.exists(full_path):
                    found_templates.append(f"✓ {template} ({full_path}) [optional]")
                    found = True
                    break
            
            if not found:
                missing_optional.append(template)
        
        # Log results
        if found_templates:
            Log.info("📁 Windows VM templates:")
            for template in found_templates:
                Log.info(f"  {template}")
        
        if missing_required:
            Log.error("❌ Missing REQUIRED templates:")
            for template in missing_required:
                Log.error(f"  {template}")
            Log.error("")
            Log.error("🚀 Quick Start - You only need Windows Server 2019:")
            Log.error("   1. Download: https://www.microsoft.com/en-us/evalcenter/download-windows-server-2019")
            Log.error("   2. Create VM: virt-install --name win2019 --ram 4096 --vcpus 2 \\")
            Log.error("      --disk path=/var/lib/libvirt/images/WinServer2019_x64.qcow2,size=60,format=qcow2 \\")
            Log.error("      --cdrom /path/to/windows-server-2019.iso --network bridge=virbr0")
            Log.error("   3. Run setup script: ./scripts/setup-libvirt-images.sh")
        
        if missing_optional and not missing_required:
            Log.info("💡 Missing optional templates (only needed for specific labs):")
            for template in missing_optional:
                Log.info(f"  {template}")
            
        if not missing_required:
            if missing_optional:
                Log.info("🎉 Core template ready! You can run most GOAD labs.")
                Log.info("💡 Add optional templates as needed for specific configurations.")
            else:
                Log.info("🎉 All Windows VM templates found!")

    def status(self):
        """Show status of VMs in the lab"""
        if not LIBVIRT_AVAILABLE:
            Log.error("libvirt-python not available")
            return
            
        conn = self._get_libvirt_connection()
        if conn is None:
            return
            
        try:
            domains = conn.listAllDomains()
            goad_domains = [d for d in domains if self.network_name.lower() in d.name().lower() or 
                           any(vm_name in d.name().lower() for vm_name in ['dc01', 'dc02', 'dc03', 'srv02', 'srv03', 'ws01'])]
            
            if not goad_domains:
                Log.info("No GOAD VMs found")
                return
                
            Log.info("GOAD VM Status:")
            for domain in goad_domains:
                state, _ = domain.state()
                state_map = {
                    libvirt.VIR_DOMAIN_NOSTATE: "No state",
                    libvirt.VIR_DOMAIN_RUNNING: "Running", 
                    libvirt.VIR_DOMAIN_BLOCKED: "Blocked",
                    libvirt.VIR_DOMAIN_PAUSED: "Paused",
                    libvirt.VIR_DOMAIN_SHUTDOWN: "Shutdown",
                    libvirt.VIR_DOMAIN_SHUTOFF: "Shut off",
                    libvirt.VIR_DOMAIN_CRASHED: "Crashed"
                }
                Log.info(f"  {domain.name()}: {state_map.get(state, 'Unknown')}")
                
        except Exception as e:
            Log.error(f"Error checking VM status: {e}")
        finally:
            conn.close()

    def start_vm(self, vm_name):
        """Start a specific VM"""
        if not LIBVIRT_AVAILABLE:
            Log.error("libvirt-python not available")
            return False
            
        conn = self._get_libvirt_connection()
        if conn is None:
            return False
            
        try:
            domain = conn.lookupByName(vm_name)
            if domain.isActive():
                Log.info(f"VM {vm_name} is already running")
                return True
            else:
                domain.create()
                Log.info(f"VM {vm_name} started")
                return True
        except libvirt.libvirtError as e:
            Log.error(f"Failed to start VM {vm_name}: {e}")
            return False
        except Exception as e:
            Log.error(f"Error starting VM {vm_name}: {e}")
            return False
        finally:
            conn.close()

    def stop_vm(self, vm_name):
        """Stop a specific VM"""
        if not LIBVIRT_AVAILABLE:
            Log.error("libvirt-python not available")
            return False
            
        conn = self._get_libvirt_connection()
        if conn is None:
            return False
            
        try:
            domain = conn.lookupByName(vm_name)
            if not domain.isActive():
                Log.info(f"VM {vm_name} is already stopped")
                return True
            else:
                domain.shutdown()
                Log.info(f"VM {vm_name} shutdown initiated")
                return True
        except libvirt.libvirtError as e:
            Log.error(f"Failed to stop VM {vm_name}: {e}")
            return False
        except Exception as e:
            Log.error(f"Error stopping VM {vm_name}: {e}")
            return False
        finally:
            conn.close()

    def destroy_vm(self, vm_name):
        """Forcefully destroy a specific VM"""
        if not LIBVIRT_AVAILABLE:
            Log.error("libvirt-python not available")
            return False
            
        conn = self._get_libvirt_connection()
        if conn is None:
            return False
            
        try:
            domain = conn.lookupByName(vm_name)
            if domain.isActive():
                domain.destroy()
                Log.info(f"VM {vm_name} destroyed")
            else:
                Log.info(f"VM {vm_name} is already stopped")
            return True
        except libvirt.libvirtError as e:
            Log.error(f"Failed to destroy VM {vm_name}: {e}")
            return False
        except Exception as e:
            Log.error(f"Error destroying VM {vm_name}: {e}")
            return False
        finally:
            conn.close()