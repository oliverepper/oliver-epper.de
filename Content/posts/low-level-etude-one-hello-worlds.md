---
date: 2022-07-29 9:41
title: Low Level Etude One – Hello Worlds
description: Connect a few dots 
tags: Assembler, ARM64, Apple Silicon, Low Level, Etude
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Hello Worlds

There is a great book about ARM64 assembler [Programming with 64-Bit ARM Assembly Language](https://books.apple.com/de/book/programming-with-64-bit-arm-assembly-language/id1512321883) from [Stephen Smith](https://smist08.wordpress.com) and the great repository [Hello Silicon](https://github.com/below/HelloSilicon) in which [Alex](https://twitter.com/avbelow) translated all the content from the book to Apple Silicon.

## Why Assembler

*Disclaimer: Don't write your software in plain Assembler!*

With that out of the way I encourage you to actually DO WRITE (at least mini-) software in Assembler, just because it can be great fun (see here: [Human Resource Machine](https://tomorrowcorporation.com/humanresourcemachine)) and – on a serious note – it might sharpen your debugging skills and you might appreciate what higher level languages can do for you – I think you even get a clearer view on what you want higher level languages to do.

## Hello World – syscall

Let's start with the first Hello World example, presented in the aformentioned resources:

```asm
; zero.s
.globl      _start
.p2align    2

_start:
            mov x0, #1
            adr x1, msg
            mov x2, #13
            mov x16, #4
            svc 0x80

            mov x16, #1
            svc 0x80

msg:        .asciz  "Hello World!\n"
```

Let's build and run:
```sh
as -o zero.o zero.s
ld -o zero zero.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _start
./zero
```

It should indeed print `Hello World` on the screen.

### What happens

`svc` is the mnemonic for `supervisor call` so it calls into the OS kernel and it calls the SYS_write syscall. How do I know? Let's check.
```sh
open `xcrun -sdk macosx --show-sdk-path`/usr/include/sys/syscall.h
```
and see for youself.

```C
// [...]
#define SYS_syscall        0
#define SYS_exit           1
#define SYS_fork           2
#define SYS_read           3
#define SYS_write          4
// [...]
```

Now you know what the last two lines do. They exit the program with whatever exit code there is in the `x0` register at that moment. Let's check:

```sh
./zero; echo $?
```

I bet the return code is `13`, how do I know that? Let's find out:
```sh
open `xcrun -sdk macosx --show-sdk-path`/usr/include/unistd.h
```
and search for ` write(`. You'll find the following declaration:
```C
ssize_t  write(int __fd, const void * __buf, size_t __nbyte) __DARWIN_ALIAS_C(write);
```

and with very little fantasy you can imagine that calling `SYS_write` will return the number of bytes written. You can even make sense of the values in the `x0, x1 and x2` registers, now. It's the file descriptor (`stdin=0, stdout=1, stderr=2`) the address of the string and its length.

_The first 8 arguments to a function go into the reigsters x0-x7, the return value can be read from x0. We will explore how functions with more (or variadic) parameters work._

Try changing the value for `__nbyte` to 5 and build and run the program again.

*Normally one would expect a well written Hello World program to exit with the exit code `0` if it was successfull and some other value otherwise (do you hear me `codesign` 🤬). So please insert a `mov x0, #0` to set the parameter to `SYS_exit` to `0` no matter what happend before that – totally ignoring error handling – if you want to replicate the `codesign` behaviour in the case of finding ambigious certificates to codesign your binary and thus not signing your binary, at all.*

### Make it more readable

You can actually use names instead of numbers if you use clang or gcc's preprocessor. Copy `zero.s` to `zero_names.S` and change it to the following:

```asm
#include <sys/syscall.h>

.globl      _start
.p2align    2

_start:
            mov x0, #1
            adr x1, msg
            mov x2, #13
            mov x16, #SYS_write
            svc 0x80

            mov x16, #SYS_exit
            svc 0x80

msg:        .asciz  "Hello World!\n"
```

Now you need a C compiler to build this:
```sh
clang -o zero_names zero_names.S -e _start
```

I will explain the reason behind `-e start` later and if I miss anything [Alex](https://twitter.com/avbelow) or [Stephen](https://smist08.wordpress.com) will have you covered.

Let's first ask another question:

### Why linking against libSystem

That's a good question. We don't use any function provided by `libSystem` in `zero.s` do we? We talk directly to the OS kernel.

Let's build what we have in plain C and see what happens:

```C
#include <unistd.h>
#include <sys/syscall.h>

int main() {
    return syscall(SYS_write, 1, "Hello World!\n", 13);
}
```

*Hey `codesign`! See what I did there returning something useful instead of `0` in every case?*

Compile it with:
```sh
clang -o zero_in_c zero_in_c.c -Wno-deprecated
```

Before we talk about the supression of the deprecation warning I want to introduce you to a really great website: [Compiler Explorer](https://godbolt.org/) by [Matt Goldbold](https://twitter.com/mattgodbolt). Open it and paste our C programm in there. Make sure to select C as the language and ARM64 as the platform. You can click [here](https://godbolt.org/z/9fq5Efz65).

This is not quite the assembler programm we wrote :-/ I mean it basically does the same, but there are three differences:

- There's some fiddeling with the stack,
- it uses `bl` to call the `syscall` function instead of `svc` and
- the addressing of the string resource is a bit more general.

There will be more etudes explaining all of this.

Back to the warning. Please delete `-Wno-deprecated` from the command above and read the following:

```pre
zero_in_c.c:5:9: warning: 'syscall' is deprecated: first deprecated in macOS 10.12 - syscall(2) is unsupported; please switch to a supported interface. For SYS_kdebug_trace use kdebug_signpost(). [-Wdeprecated-declarations]
        return syscall(SYS_write, 1, "Hello World!\n", 13);
               ^
/Applications/Xcode-14.0.0-Beta.3.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/unistd.h:746:6: note: 'syscall' has been explicitly marked deprecated here
int      syscall(int, ...);
         ^
1 warning generated.
```

Let me translate this for you:

> "Please don't talk to our kernel directly! Use the APIs we provide!".

Wait there is even something between the lines:

> "We could change the layout and the numbering of the syscalls anytime without telling you, because we know you will only use our APIs and we'll update them alongside our kernel. So everything will work fine!"

Fair enough! We have been warned.

Now you know the reason we need to link even our first version of the Hello World program to `libSystem`. This is the lowest ground where Apple wants us to live. In fact neither Alex nor I manged to build a Mach executable without linking it to `libSystem`.

You can link it:

```
ld -o zero zero.o -e _start -static
```

But you cannot start it. (Is there a way? Please tell me!)

### Improved Hello World – syscall

One thing that I found annoying right away is having to provide the length of the string. Stephens book has a neat trick for that:

```asm
; zero_length.s
.globl      _start
.p2align    2

_start:
            mov x0, #1
            adrp x1, msg@PAGE
            add x1, x1, msg@PAGEOFF
            adrp x2, msg_sz@PAGE
            add x2, x2, msg_sz@PAGEOFF
            ldr x2, [x2]
            mov x16, #4
            svc 0x80

            mov x16, #1
            svc 0x80

.data
msg:        .asciz  "Hello World!\n"
msg_sz:     .word   .-msg
```

For this to work we needed to move the string `msg` out of the explicit text section of our program into the data section. `Text section` can be read and executed, `data section` can be read and written, not executed!

Untill now we could load the string in `msg` with `adr reg, msg`. That generated an address relative to the pc register. *I encourage you to read Stephens book to find out how ARM64 manages it to put 64 bit addresses into opcodes that are only 64 bit long.* Now we need to use `adrp` and `add`. `adrp` gives us the address to the memory page that holds `msg` and add adds the approriate offset.

Let's evaluate that the line `add x1, x1, msg@PAGEOFF` does in fact add nothing to x1, because `msg` has zero offset from the page start.

Build the programm and run it with
```sh
lldb zero_length
```

Once in lldb enter `b start` and then `r`. Now you can see it already:

```pre
->  0x100003f90 <+0>:  mov    x0, #0x1
    0x100003f94 <+4>:  adrp   x1, 1
    0x100003f98 <+8>:  add    x1, x1, #0x0              ; msg
    0x100003f9c <+12>: adrp   x2, 1
```

`msg` lives at 0 offset. Enter `n` 3 times and then `re r x1` to see the content of the x1 register (_re_ gister _r_ ead x1). Copy the value and enter:

```
m read 0x0000000100004000
```

`0x0000000100004000` being the value from x1.

Now step again two times and see whats in `x2`

```pre
(lldb) re r x2
      x2 = 0x000000010000400e  msg_sz
```

check the memory at that address:
```pre
0x10000400e: 0e 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
0x10000401e: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
```

So the value is `0e` which is 14 in decimal.
`ldr x2, [x2]` loads the value from the address in x2 to the x2 register.

So the assembler evaluated `.` to the current memory address which is right after `msg` and `-msg` subtracts the offset of `msg` giving you its length + 1. So actually it should read:

```asm
.data
msg:        .asciz  "Hello World!\n"
msg_sz:     .word   .-msg-1
```

Let's check in the debugger:

```pre
(lldb) re r x2
      x2 = 0x000000000000000d
```

That's 13!

## Hello World - puts or printf?

Ok. We learned that we're not supposed to talk to the OS kernel directly. How would a reasonable C Hello World example look in assembler anyway.

```C
int main() {
    return puts("Hello World!");
}
```

Put that into [Compiler Explorer](https://godbolt.org) and get:
(You can click [here](https://godbolt.org/z/aYfcEfzKc))

```asm
.LC0:
        .string "Hello World!"
main:
        stp     x29, x30, [sp, -16]!
        mov     x29, sp
        adrp    x0, .LC0
        add     x0, x0, :lo12:.LC0
        bl      puts
        ldp     x29, x30, [sp], 16
        ret
```

We understand the addressing already, but we need to learn about `bl - branch with link` and the stack next.

Before we do that. I just want to try out something else. Copy `zero.s` to `zero_no_symbols.s` and change it to the following:

```asm
; zero_no_symbols.s

.globl      _start
.p2align    2

_start:
            mov x0, #0                  // 0
            adr x1, #0x18               // 4
            mov x2, #13                 // 8        + 4
            mov x16, #4                 // 12       + 8
            svc 0x80                    // 16       + 12

            mov x16, #1                 // 20       + 16
            svc 0x80                    // 24       + 20

msg:        .asciz  "Hello World!\n"    // 28       + 24 = 0x18
```

Instead of using `adr x1, msg` you can simply count instructions and calculate the position of `msg` yourself. Darwin wants everything aligned on 4 byte boundaries. That is what `p2align 2` does. So you can see that the second instruction is 4 bytes from the program start and `msg` is 24 bytes from the pc register after the first instruction is executed (the pc register (_p_ rogramm _c_ ounter) always has the next line that is going to be executed). So since 24 is 0x18 in hex we can put that there instead of `msg`. Pretty useless, but helpful to understand.

To prove all this execute:

```sh
lldb zero
```

and enter `b start` then `r` and `dis`:

```pre
zero`start:
->  0x100003f8c <+0>:  mov    x0, #0x1
    0x100003f90 <+4>:  adr    x1, #0x18                 ; msg
    0x100003f94 <+8>:  mov    x2, #0x5
    0x100003f98 <+12>: mov    x16, #0x4
    0x100003f9c <+16>: svc    #0x80
    0x100003fa0 <+20>: mov    x16, #0x1
    0x100003fa4 <+24>: svc    #0x80
```

Enter `n` one time and then check the pc register `re r pc`

```pre
(lldb) re r pc
      pc = 0x0000000100003f90  zero`start + 4
```

Add `24` to `0x0000000100003f90` which is `0x0000000100003fa8` and then enter `m read 0x0000000100003fa8`:

```pre
(lldb) m read 0x0000000100003fa8
0x100003fa8: 48 65 6c 6c 6f 20 57 6f 72 6c 64 21 0a 00 00 00  Hello World!....
0x100003fb8: 01 00 00 00 1c 00 00 00 00 00 00 00 1c 00 00 00  ................
```

See! There's your `msg`.


[Part 2](https://oliver-epper.de/posts/low-level-etude-one-hello-worlds-part2/)

## Links

Oh! By the way if you want your own Linux syscall to play with start here: [Implementing a Linux syscall](https://oliver-epper.de/posts/implementing-a-linux-syscall/)