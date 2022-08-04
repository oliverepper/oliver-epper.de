---
date: 2022-08-04 9:41
title: Low Level Etude One – Hello Worlds (Part 3)
description: Connect a few dots
tags: Assembler, ARM64, Apple Silicon, Low Level, Etude
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Hello World - bare metal

[Part 2](https://oliver-epper.de/posts/low-level-etude-one-hello-worlds-part2/)

To finish this first etude lets demo one more Hello World program. There are many options, but I stumbled upon another great resource on the internet that's worth mentioning: The [OSDev.org Wiki](https://wiki.osdev.org/Main_Page). They have a wonderful Hello World example here: [QEMU AArch64 Virt Bare Bones](https://wiki.osdev.org/QEMU_AArch64_Virt_Bare_Bones).

They do the following:

```asm
.globl            _start

_start:
                  ldr x30, =stack_top
                  mov sp, x30
                  bl kmain
                  b .
```

This is the boot code. It basically sets up the stack and jumps into the `kmain` function. If that returns the last line will loop forever.

```C
#include <stdint.h>

volatile uint8_t *uart = (uint8_t *) 0x09000000;

void putchar(char c) {
      *uart = c;
}

void print(const char *s) {
      while (*s != '\0') {
            putchar(*s);
            s++;
      }
}

void kmain(void) {
      print("Hello World!\n");
}
```

There's your _kernel_. Since we are no longer in a hosted environment we need to build a `print` function ourselfs. Don't forget the volatile keyword if you talk to memory mapped hardware resources, otherwise the compiler will optimize away every assignment but the last.

```ld
ENTRY(_start)
SECTIONS {
      . = 0x40000000;
      .startup . : { boot.o(.text) }
      .text : { *(.text) }
      .data : { *(.data) }
      .bss : { *(.bss COMMON) }
      . = ALIGN(8);
      . += 0x1000; /* 4kb of stack memory */
      stack_top = .;
}
```

This is the linker configuration that helps produce the `ELF` file that we need. You can install the required compiler and tools via `brew install aarch-elf-gcc qemu`.

Build the kernel via:

```sh
aarch64-elf-as -o boot.o boot.s                                   
aarch64-elf-gcc -ffreestanding -c kernel.c -o kernel.o            
aarch64-elf-ld -nostdlib -Tlinker.ld boot.o kernel.o -o kernel.elf
```

And run it via:

```sh
qemu-system-aarch64 -machine virt -cpu cortex-a57 -kernel kernel.elf -nographic
```

The OS Dev wiki examples ends here. If you tried it you have the qemu process running in an endless loop, now (`b .`). Let's try to fix that.

I have no clue (yet) how a real OS performs shutdown or reboot but we can use the semihosting interface [What is semihosting?](https://developer.arm.com/documentation/dui0471/g/Bgbjjgij) of the ARM CPU to tell qemu that our software has finished execution. [How to cleanly exit QEMU after executing bare metal program without user intervention?](https://stackoverflow.com/questions/31990487/how-to-cleanly-exit-qemu-after-executing-bare-metal-program-without-user-interve/49930361#49930361)


```asm
.globl            _start


shutdown:
                  mov x0, #0x18
                  hlt 0xf000

_start:
                  ldr x30, =stack_top
                  mov sp, x30
                  bl kmain
                  b shutdown
```

If I understand this right, the above makes qemu call SYS_exit through the semihosting interface on our behalf. Now we need to add the `-semihosting` option to qemu and indeed the process returns.