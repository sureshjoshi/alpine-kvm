#! /bin/sh 

# Creates a headless Debian Linux virtual machine with sane defaults

set -e

# Set defaults for the VM name, number of CPUs, amount of memory, and disk size
CPUS=2
MEMORY_MB=4096
DISK_GB=10

while getopts ":hc:d:m:n:" arg; do
    case $arg in
        c) CPUS=${OPTARG};;
        d) DISK_GB=${OPTARG};;
        m) MEMORY_MB=${OPTARG};;
        n) VM_NAME=${OPTARG};;
        h | *) echo "Usage: $0 [-c cpus] [-d disk (GB)] [-m memory (MB)] [-n name]"; exit 0;;
    esac
done

if [ -z $VM_NAME ]; then
    echo "VM name not specified..."
    exit 1
fi

virt-install \
  --connect qemu:///system \
  --disk size=$DISK_GB,format=raw,bus=virtio \
  --extra-args="console=ttyS0,115200n8 serial" \
  --graphics none \
  --hvm \
  --location https://debian.osuosl.org/debian/dists/stable/main/installer-amd64/ \
  --memory $MEMORY_MB \
  --name $VM_NAME \
  --osinfo debian12 \
  --network network=default,model=virtio \
  --vcpus $CPUS \
  --virt-type kvm
