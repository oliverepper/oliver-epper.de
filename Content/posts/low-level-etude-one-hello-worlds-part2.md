---
date: 2022-07-31 9:41
title: Low Level Etude One – Hello Worlds (Part 2)
description: Connect a few dots 
tags: Assembler, ARM64, Apple Silicon, Low Level, Etude
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Hello World - puts or printf?

[Part 1](https://oliver-epper.de/posts/low-level-etude-one-hello-worlds/)

### bl - branch with link

Let's get back on track and learn about `bl`. Consider the following simple program:

```asm
.globl      _start
.p2align    2

say_hello:
            mov x0, #1
            adrp x1, msg@PAGE
            add x1, x1, msg@PAGEOFF
            adrp x2, msg_sz@PAGE
            add x2, x2, msg_sz@PAGEOFF
            ldr x2, [x2]
            mov x16, #4
            svc 0x80

_start:
            b say_hello
            mov x16, #1
            svc 0x80


.data
msg:        .asciz  "Hello World!"
msg_sz:     .word   .-msg-1
```

If you build and start this it will print `Hello World` forever. The `b - branch` instruction will jump to `say_hello` and continue execution after `say_hello` with the next line which is the same branch instruction, thus repeating forever.

So we need to change `b` to `bl - branch with link` and at the end of the `say_hello` block we add a `ret` instruction. Now the execution will continue right after the `bl say_hello` instruction. This happens because `bl` saves the address of the next instruction into the `lr` register and `ret` jumps to the address saved in the `lr` register.

**But!** What if we override the `lr` registers content with another `bl` instruction? Let's add the following:

```asm
.globl      _start
.p2align    2

print_newline:
            mov x0, #1
            adrp x1, newline@PAGE
            add x1, x1, newline@PAGEOFF
            mov x2, #1
            mov x16, #4
            svc 0x80
            ret

say_hello:
            mov x0, #1
            adrp x1, msg@PAGE
            add x1, x1, msg@PAGEOFF
            adrp x2, msg_sz@PAGE
            add x2, x2, msg_sz@PAGEOFF
            ldr x2, [x2]
            mov x16, #4
            svc 0x80
            bl print_newline
            ret

_start:
            bl say_hello
            mov x16, #1
            svc 0x80


.data
msg:        .asciz  "Hello World!"
msg_sz:     .word   .-msg-1
.align 4
newline:    .asciz  "\n"
```

Can you already see the problem? With `bl print_newline` we save another address to the `lr` register and overwrite what was already saved. So once we call `ret` from `print_newline` we'll fall on the `ret` instruction at the end of `say_hello` which is another `ret` statement that will jump to that very location, again. So we're in an endless loop.

The easy fix is to just save the content of the `lr` register before the `bl` instruction and restore if before the `ret` instruction:

```asm
say_hello:
            mov x0, #1
            adrp x1, msg@PAGE
            add x1, x1, msg@PAGEOFF
            adrp x2, msg_sz@PAGE
            add x2, x2, msg_sz@PAGEOFF
            ldr x2, [x2]
            mov x16, #4
            svc 0x80
            mov x3, lr
            bl print_newline
            mov lr, x3
            ret
```

Beware that this will only work if the code that we jump into will not fiddle with the `x3` register that we used to save the content of the `lr` register.

### Function call convention

So what is the right way to make a proper function call in arm64 assembler? [Stephens Book](https://books.apple.com/de/book/programming-with-64-bit-arm-assembly-language/id1512321883) has a nice summary:

**For the calling routine:**

- Save registers `x0 - x18` if you use them.
- Move the first eight parameters into the registers `x0 - x7`. _Functions with varadic parameters might be handled differently, we'll come to that_
- Push additional parameters on the stack.
- Use `bl` to call the function.
- Evalute the return code in `x0`.
- Restore `x0 - x18`, if needed.


**For the called function:**

- Push `lr` and `x19 - x30` onto the stack if used in the routine.
- Do the work.
- Put return code in `x0`
- Pop `lr` and `x19 - x30` if pushed in step 1.
- Use `ret` instruction.


So that's no quite what we have been doing. Let's double check what clang did for us, again:

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

The first line stores a pair (_st_ ore _p_ air) of registers on the stack after subtracting 16 from `sp`. `sp` is the stack pointer that holds the currect position of the stack. Since the stack grows in negative direction subtracting 16 makes room to save the contents of two registers.

Let's check what the two registers are. Start `lldb two` and enter `b start` and `r`. Now type `re r`.

```pre
General Purpose Registers:
        x0 = 0x0000000000000001
        x1 = 0x000000016fdff618
        x2 = 0x000000016fdff628
        x3 = 0x000000016fdff778
        [...]
       x27 = 0x0000000000000000
       x28 = 0x0000000000000000
        fp = 0x000000016fdff5f0
        lr = 0x000000010000d08c  dyld`start + 520
        sp = 0x000000016fdff4b0
        pc = 0x0000000100003f8c  zero`start
      cpsr = 0x60001000
```

So `x29` is the frame pointer and `x30` is the link register. Let's explore this with a minimal sample program:

```asm
.globl      _start
.p2align    2


_start:
            stp fp, lr, [sp, -16]!
            mov fp, sp

            ; work

            ldp fp, lr, [sp], 16
            ret
```

Build the program and start it in the debugger breaking on start. Let's explore the stack:

```pre
(lldb) re r sp
      sp = 0x000000016fdff460
(lldb) m read 0x000000016fdff460
0x16fdff460: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
0x16fdff470: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
```

Execute the first instruction and check again:

```pre
(lldb) re r sp
      sp = 0x000000016fdff450
(lldb) m read 0x000000016fdff450
0x16fdff450: a0 f5 df 6f 01 00 00 00 8c d0 00 00 01 00 00 00  ...o............
0x16fdff460: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
```

Let's check if that looks like it should:

```pre
(lldb) re r fp
      fp = 0x000000016fdff5a0
(lldb) re r lr
      lr = 0x000000010000d08c  dyld`start + 520
```

Looks pretty good. Indeed the stack pointer got decremented by 16 bytes making room for the two 8 byte values saved in `fp` and `lr` and then they got pushed onto the stack. (In little endian byte order!)
Next we move the `fp - frame pointer` to the new position of the stack pointer so that the called function can construct a stack frame that can hold its local variables if needed.
After the work is done we pop back `fp` and `lr` and are safe to call `ret`.

So let's rewrite our last hello world example a little bit:

```asm
say_hello:
            stp fp, lr, [sp, -16]!
            mov fp, sp

            mov x0, #1
            adrp x1, msg@PAGE
            add x1, x1, msg@PAGEOFF
            adrp x2, msg_sz@PAGE
            add x2, x2, msg_sz@PAGEOFF
            ldr x2, [x2]
            mov x16, #4
            svc 0x80
            bl print_newline
            
            ldp fp, lr, [sp], 16
            ret
```

So far so good!

### Variadic parameters

Now let's write a `printf` driven Hello World program. Since `printf` uses variadic parameters we cannot use the registers `x1 - x7` for all but the first parameter. The call convention simply differs. The variadic parameters go on the stack. Let's see how this is done:

```asm
.globl            _start
.p2align          2

                  .equ variadic_param_1, 0

say_hello:
                  stp fp, lr, [sp, #-16]!
                  sub sp, sp, #16
                  mov fp, sp

                  adrp x0, format_str@PAGE
                  add x0, x0, format_str@PAGEOFF

                  adrp x1, msg@PAGE
                  add x1, x1, msg@PAGEOFF

                  str x1, [fp, #variadic_param_1]

                  bl _printf

                  add sp, sp, #16
                  ldp fp, lr, [sp], #16
                  ret

_start:
                  stp fp, lr, [sp, #-16]!
                  mov fp, sp

                  bl say_hello

                  ldp fp, lr, [sp], #16
                  ret

format_str:       .asciz      "%s\n"

.data
msg:              .asciz      "Hello World!"

```

The `equ` directive gives a symbolic name to a numeric constant. We will reserve some space on the stack for the variadic parameters, and the first one will go in the first bucket, hence the 0 offset. After storing `fp` and `lr` onto the stack we move the stack pointer and our frame pointer 16 bytes further. This will give us room for 2 64 bit values. We only need one, but the `sp` needs to be 16 byte aligned on Dariwn.
After we loaded the address of `msg` into the `x1` register we can save it to our stack-frame (which can hold 2 64bit values). Since that is where the stack-pointer points to, that's also where `printf` will be looking for it's first variadic parameter if the format string requires it.

You can play with a second variadic parameter and make another symbolic name: `.equ variadic_param_2, 8` or just store the second value to our stack frame using: `str reg, [fp, #8]` instead of `str reg, [fp, #variadic_param_2]`.

[Part 3](https://oliver-epper.de/posts/low-level-etude-one-hello-worlds-part3/)