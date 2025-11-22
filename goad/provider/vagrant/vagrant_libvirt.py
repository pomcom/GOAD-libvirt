from goad.provider.vagrant.vagrant import VagrantProvider
from goad.utils import *


class VagrantLibvirtProvider(VagrantProvider):
    provider_name = "vagrant-libvirt"
    default_provisioner = PROVISIONING_LOCAL
    allowed_provisioners = [PROVISIONING_LOCAL, PROVISIONING_RUNNER, PROVISIONING_DOCKER, PROVISIONING_VM]

    def check(self):
        checks = [
            super().check(),
            self.command.check_libvirt(),
            self.command.check_vagrant_plugin('vagrant-libvirt', True)
        ]
        return all(checks)