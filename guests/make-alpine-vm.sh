#! /bin/sh 

# Creates a headless Alpine Linux virtual machine with sane defaults

set -e

# Set defaults for the VM name, number of CPUs, amount of memory, and disk size
CPUS=2
MEMORY_MB=4096
DISK_GB=10
ISO_PATH="alpine-standard-3.20.1-x86_64.iso"

while getopts ":hc:d:i:m:n:" arg; do
    case $arg in
        c) CPUS=${OPTARG};;
        d) DISK_GB=${OPTARG};;
        i) ISO_PATH=${OPTARG};;
        m) MEMORY_MB=${OPTARG};;
        n) VM_NAME=${OPTARG};;
        h | *) echo "Usage: $0 [-c cpus] [-d disk (GB)] [-i ISO path] [-m memory (MB)] [-n name]"; exit 0;;
    esac
done

if [ -z $VM_NAME ]; then
    echo "VM name not specified..."
    exit 1
fi

virt-install \
  --cdrom $ISO_PATH \
  --connect qemu:///system \
  --disk size=$DISK_GB,format=raw,bus=virtio \
  --graphics none \
  --hvm \
  --memory $MEMORY_MB \
  --name $VM_NAME \
  --osinfo alpinelinux3.19 \
  --network network=default,model=virtio \
  --vcpus $CPUS \
  --virt-type kvm
