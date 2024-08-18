---
date: 2024-03-11 9:42
title: Poudriere on Apple Silicon
description: Building FreeBSD ports for aarch64 on a Apple Silicon Mac
tags: FreeBSD, poudriere, qemu, LaunchDaemon, ports
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

I have updated the FreeBSD package for pjsip and volunteered to take over the maintainership of that package. To me arm/aarch64 is even more important than amd64 so naturally I wanted to build or at least test the package on aarch64. The normal way in FreeBSD is to run poudriere together with qemu emulation for cross-building but that takes literally forever and wasn't even successful.

What works really well is running FreeBSD for aarch64 under qemu virtualization with Apples hypervisor. In fact that is so slick that I've setup LaunchDaemon to always start FreeBSD together with macOS.

## Qemu Configuration

Sadly there is a bug with qemu/Hypervisor Framework that affects ipv6 in the guest when bridging is used and the bridge connects to the local network via WiFi. When the virtio network connects to a bridge that is connected via WiFi the guest can successfully obtain an ipv6 address via router advertisement, but it canot receive packages via ipv6 (very strange!). Ipv4 is fine. Ipv6 over a shared connection is fine. Ipv6 over the bridged connection is fine, if the bridge is not connected via WiFi.

So if you use a Mac Mini as a build server and plug in a cable you are absolutely fine. If you need WiFi you cannot use the bridge if you need ipv6 😕 I hope this will get fixed. Any pointers are very welcome!

The qemu-config is more or less straight-forward:

```pre
#!/usr/bin/env bash

BASEDIR="$(dirname "$0")"

/opt/homebrew/bin/qemu-system-aarch64 \
        -nodefaults \
        -vga none \
        -device virtio-gpu \
        -display cocoa,show-cursor=on \
        -cpu host \
        -smp cpus=4,sockets=1,cores=2,threads=2 \
        -machine virt \
        -accel hvf \
        -m 4096 \
        -drive if=pflash,format=raw,unit=0,file.filename="${BASEDIR}"/edk2-aarch64-code.fd,file.locking=off,readonly=on \
        -drive if=pflash,format=raw,unit=1,file="${BASEDIR}"/edk2-arm-vars.fd \
        -device virtio-net-pci,netdev=net0 \
        -netdev vmnet-shared,id=net0 \
        -device nec-usb-xhci,id=usb-bus \
        -device usb-tablet,bus=usb-bus.0 \
        -device usb-mouse,bus=usb-bus.0 \
        -device usb-kbd,bus=usb-bus.0 \
        -device virtio-blk-pci,drive=drive0,bootindex=0 \
        -drive if=none,file="${BASEDIR}"/one.qcow2,format=qcow2,media=disk,id=drive0,discard=unmap,detect-zeroes=unmap \
        -device virtio-blk-pci,drive=drive1,bootindex=1 \
        -drive if=none,file="${BASEDIR}"/two.qcow2,format=qcow2,media=disk,id=drive1,discard=unmap,detect-zeroes=unmap \
        -device usb-storage,drive=cd,removable=true,bootindex=2,bus=usb-bus.0 \
        -drive if=none,file="${BASEDIR}"/FreeBSD-14.0-RELEASE-arm64-aarch64-bootonly.iso,readonly=on,media=cdrom,id=cd \
        -device virtio-rng-pci \
        -boot menu=on,splash-time=0 \
        -nographic \
        -name poudriere
```

Save this in `/opt/VMs/poudriere/start.sh`. Delete the line that says `-nographic` for now, or for good if you always want a display to the build machine. I don't. I prefer connecting via ssh and never want to interact with the machine directly.

**Hint:** If you use a cable connection you can use bridged-networking. You should give your device a permanent mac-address, too:

```pre
-device virtio-net-pci,mac=52:54:00:xx:xx:xx,netdev=net0 \
-netdev vmnet-bridged,id=net0,ifname=en0 \
```

### Create the disks

I use two disks. `one.qcow2` for the system and `two.qcow2` for poudriere and the ports collection. Create them with:

```bash
qemu-img create -f qcow2 one.qcow2 10G
qemu-img create -f qcow2 two.qcow2 128G
```

You can use raw files and they will be faster but then you need a slighty modified config:

```bash
mkfile 10G one.raw
```

```pre
-device virtio-blk-pci,drive=drive0,bootindex=0 \
-drive if=none,file=./raw/disk.raw,format=raw,media=disk,id=drive0 \
```

I go with the slower qcow2 files mainly because they are sparse files and I cannot afford to give up so much disk space.

### Copy the EFI and EFI vars file in place

Depending on the guest operating system there are different ways you can bring up a guest machine. I choose EFI for all my machines because it works with every modern guest os. So once you have qemu installed via `brew install qemu` you can either copy the UEFI-firmware and the UEFI variables storage file in place or change the path to the UEFI file in the VM config. Don't use on variable storage for multiple machines, though.

```bash
cp /opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-aarch64-code.fd /opt/VMs/poudriere/
cp /opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-arm-vars.fd /opt/VMs/poudriere/
```

## First Start & Installation

Make sure that you have deleted the line `-nographic` and then invoke the script. You need `sudo` in order for the qemu helper to setup the bridge.

`sudo ./start.sh`

The VM should boot like a normal computer and you can install FreeBSD.

**Hint:** The computer will start with an EFI shell. Type exit and you will be presented with a UI where you can choose your boot device.

## FreeBSD Initial Config

This is optional but I find it useful.

+ In order to speed up the start of the virtual machine add this to `/boot/loader.conf`:

```pre
autoboot_delay="-1"
beastie_disable="YES"
```

Make sure that you can reach the machine via ssh so that you can add `-nographic` back to the VM config. You should be able to restart the machine via `reboot` and to stop the VM via `init 0`.

## LaunchDaemon

If you want the machine to be automatically started via LaunchDamon create the following file in `/Library/LaunchDemon/de.oliver-epper.VMs.poudriere.plist`:

```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple/DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
        <key>Label</key>
        <string>de.oliver-epper.VMs.poudriere</string>
        <key>Program</key>
        <string>/opt/VMs/poudriere/start.sh</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>StandardOutPath</key>
        <string>/opt/VMs/poudriere/out</string>
        <key>StandarderrorPath</key>
        <string>/opt/VMs/poudriere/err</string>
</dict>
</plist>
```

and install the service with `sudo launchctl load /Library/LaunchDaemons/de.oliver-epper.VMs.poudriere.plist`.

## Poudriere

Before installaing poudriere let's create a zpool and the approrpriate filesystems. To use two.qcow2 as a zfs pool enter:

```bash
zpool create tank /dev/vtbd1
```

and then create `/usr/local/poudriere` and `/usr/ports/distfiles`:

```bash
zfs create -o mountpoint=/usr/local/poudriere tank/poudriere
zfs create -o mountpoint=/usr/ports/disfiles tank/distfiles
```

### Signing the Packages

In order for poudriere to sign the packages it needs a key:

```bash
mkdir -p /usr/local/etc/ssl/keys
mkdir -p /usr/local/etc/ssl/certs
chmod 0600 /usr/local/etc/ssl/keys

openssl genrsa -out /usr/local/etc/ssl/keys/poudriere.key 4096
openssl rsa -in /usr/local/etc/ssl/keys/poudriere.key -pubout -out /usr/local/etc/ssl/certs/poudriere.cert
```

### Poudriere Config

Edit `/usr/local/etc/poudriere.conf` according to your needs. I chaned the following:

```pre
zpool=tank
FREEBSD_HOST=your_mirror
GIT_PORTSURL=your_github, or official github mirror
PKG_REPO_SIGNING_KEY=/usr/local/etc/ssl/keys/pouriere.key
```
