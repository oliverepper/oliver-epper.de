---
date: 2021-11-03 9:41
title: Implementing a Linux syscall
description: Implement a syscall in the Linux kernel and call it from userspace
tags: Linux, C
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Why

Honestly, no good reason at all. I am neither a C programmer, nor a kernel hacker. But that said I am curious and this sounds like fun and I get to build a kernel again. Last time must have been 2.something ;)

*Spoiler*:
Moores Law is not true. It took like 20 minutes to build a kernel 20 years ago, and it still takes 20 minutes ;)

## Disclaimer

This is not my own work, I just searched a little bit on the internet. There is good documentation on [kernel.org](https://www.kernel.org/doc/html/latest/process/adding-syscalls.html?highlight=syscall_define) and I got the idea from [Stephen Brennan](https://brennan.io/2016/11/14/kernel-dev-ep3/). I've just searched where to put the things for a linux version 5 arm build.

## Let's start

First I'd recommend to setup a virtual Debian install. I know there are a bunch of nice distributions out there but I used Debian for a long time so that's what I prefer. Furthermore I need something with good aarch64 support since I'm going to play with this on a Mac.

I tried both Parallels and UTM and for this purpose both should work. You can install UTM via brew: `brew install utm`. Download a Debian installer and make the ISO available to the virtual machine. Please use more than 10GB for the virtual harddrive, you'll need it.

## Tools
It is advisable to install the Parallels Tools for better performance if you go with Paralles. You can do that as root with
```bash
mount /dev/cdrom /media/cdrom0
```
and then start the cli installer.

While you're at it enter
```bash
/sbin/adduser <your_username> sudo
```
for later. Then run `sync && init 6`.

## The requirements

After updating install the following packages:
```bash
sudo apt-get install build-essential linux-source bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves rsync
```

## Build the kernel

Now you can unpack the kernel sources in your home directory:
```bash
tar xavf /usr/src/linux-source-5.10.tar.xz
```

Since we don't want to change the kernel-config we can just copy the running config.
```bash
cd linux-source-5.10
cp /boot/config-5.10.0-9-arm64 .config
```

Edit the `.config` file and enter this
`CONFIG_SYSTEM_TRUSTED_KEYS = ""`

And then run
```bash
make oldconfig
```

To build the kernel packages run
```bash
nice make -j`nproc` bindeb-pkg
```

## Implement the syscall

In `include/uapi/asm-generic/unistd.h`

```C
#define __NR_demo 441
__SYSCALL(__NR_demo, sys_demo)

#undef __NR_syscalls
#define __NR_syscalls 442
```

In `kernel/sys.c`

```C
/*
 * https://brennan.io/2016/11/14/kernel-dev-ep3/
 */ 
SYSCALL_DEFINE1(demo, char *, msg)
{
       char buf[256];
       long copied = strncpy_from_user(buf, msg, sizeof(buf));
       if (copied < 0 || copied == sizeof(buf))
               return -EFAULT;
       printk(KERN_INFO "demo called with '%s'\n", buf);
       return 0;
}
```

## and the userspace programm

```C
/*
 * https://brennan.io/2016/11/14/kernel-dev-ep3/
 */ 
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <stdio.h>

#define SYS_demo 441

int main(int argc, char **argv)
{
        if (argc <= 1) {
                printf("Must provide a log string\n");
                return -1;
        }

        char *arg = argv[1];
        printf("Making call with '%s'\n", arg);
        long res = syscall(SYS_demo, arg);
        printf("System call returned %ld.\n", res);
        return res;
}
```

## Install the kernel

If you're using Parallels this would be a good time to take a snapshot, just in case ;)

```bash
sudo dpkg --install linux-image-5.10.70-dbg_5.10.70-1_arm64.deb
sync
sudo init 6
```

## Test the thing

```bash
gcc -o demo demo.c
./demo "but why?"
sudo dmesg
./demo "For the fun of it ;)"
```

```pre
[   55.833906] demo called with 'but why?'
[   71.208406] demo called with 'For the fun of it ;)'
```
