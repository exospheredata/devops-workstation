#!/bin/sh -eux

# set a default HOME_DIR environment variable if not set
HOME_DIR="${HOME_DIR:-/home/vagrant}";

case "$PACKER_BUILDER_TYPE" in
vmware-iso|vmware-vmx|vsphere-iso)
    yum remove -y open-vm-tools
    mkdir -p /tools-iso /tmp/vmware-tools
    mount /dev/sr1 /tools-iso
    cp /tools-iso/VMwareTools-* /tmp/vmware-tools/vmware-tools.tar.gz
    umount /tools-iso
    rmdir /tools-iso
    tar -xf /tmp/vmware-tools/vmware-tools.tar.gz --directory /tmp/vmware-tools
    /tmp/vmware-tools/vmware-tools-distrib/vmware-install.pl --default --force-install
    ;;
esac
