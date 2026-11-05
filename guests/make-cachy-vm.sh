#! /bin/sh

# Creates a CachyOS virtual machine with GPU passthrough
# This is entirely computer-specific, since it hardcodes the hostdev values, and the inputs

set -e

# Set defaults for the VM name, number of CPUs, amount of memory, and disk size
CPUS=4
THREADS=2
MEMORY_MB=8192
DISK="/dev/nvme1n1"
ISO_PATH="cachyos-desktop-linux-260809.iso"

while getopts ":hc:d:i:m:n:v:" arg; do
    case $arg in
        c) CPUS=${OPTARG};;
        d) DISK=${OPTARG};;
        i) ISO_PATH=${OPTARG};;
        m) MEMORY_MB=${OPTARG};;
        n) VM_NAME=${OPTARG};;
        t) THREADS=${OPTARG};;
        h | *) echo "Usage: $0 [-c cpus] [-d disk (path)] [-i ISO path] [-m memory (MB)] [-n name] [-t threads per core]"; exit 0;;
    esac
done

if [ -z $VM_NAME ]; then
    echo "VM name not specified..."
    exit 1
fi

# There is an implicit VCPU setting of socket * cores * threads (e.g. 1 socket, 4 cores, 2 threads = 8 VCPU)
# TODO: Check out the nuance/distinction between a VM core, a QEMU thread, and a Intel CPU thread

# 01:00 is my GPU's audio and video controllers
# TODO: 03:00 is my /dev/nvme1n1 (--hostdev 03:00.0,address.type=pci), but requires the modprobe to be updated
virt-install \
    --boot uefi \
    --cdrom $ISO_PATH \
    --connect qemu:///system \
    --cpu host-passthrough,cache.mode=passthrough,topology.sockets=1,topology.dies=1,topology.cores=$CPUS,topology.threads=$THREADS \
    --debug \
    --features kvm.hidden.state=on \
    --graphics none \
    --hostdev 01:00.0,address.type=pci,address.multifunction=on \
    --hostdev 01:00.1,address.type=pci \
    --disk $DISK,format=raw,bus=virtio,cache=none,driver.io=native,driver.discard=unmap,driver.queues=$(($CPUS * $THREADS)) \
    --hostdev 0x8087:0x0033,address.type=usb \
    --hvm \
    --input evdev,source.dev=/dev/input/by-id/usb-Microsoft_Wired_Keyboard_600-event-kbd,source.grab=all,source.repeat=on,source.grabToggle=ctrl-ctrl \
    --input evdev,source.dev=/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse \
    --input keyboard,bus=virtio \
    --input mouse,bus=virtio \
    --memory $MEMORY_MB \
    --name $VM_NAME \
    --network network=default,model=virtio \
    --osinfo archlinux \
    --virt-type kvm 
