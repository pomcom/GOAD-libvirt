version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - ${ip}/${netmask}
    gateway4: ${gateway}
    nameservers:
      addresses:
        - ${dns}
      search: []