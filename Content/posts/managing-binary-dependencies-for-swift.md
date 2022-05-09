---
date: 2022-04-22 9:41
title: Managing binary dependencies for swift
description: Make PjSIP Project available for mutiple architectures and targets
tags: pjsip, pjproject, cmake, pkg-config, Swift, C, C++
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## The problem

One of the core dependencies for my employer is the [PjSIP Project](https://www.pjsip.org). As many others libraries it
is written in C for maximum compatibility. Modernizing parts of our stack I wanted a single swift package `PjSIP` that I can rely on with no further fiddeling.

To be useable it needed to support at least the following environments: macOS (Intel and Apple Silicon), iPhoneOS and iPhone Simulator running on Apple Silicon. PjSIP project is a complex library to begin with and the above are four builds, already.
So we want to build them in a controlled fashion and use as binary dependency.

## XCFramework
XCFrameworks handle the above well. They can contain libraries for multiple platforms (and variants!) and the libraries can even be fat-libs so we get everything we need.

So the first step was to create an XCFramework. You can see how it's done here [pjproject-apple-platforms](https://github.com/oliverepper/pjproject-apple-platforms/blob/main/start.sh) beginning at around line 150 `cat << 'END' > pjproject/build_apple_platforms.sh`. Basically we build the object files and pack them together with `libtool`.

XCFrameworks are simple: The build system sees them, reads their `Info.plist` and copies the appropriate library to your build folder before the build. So speaking in C-lingo `-lpjproject` will be happy.


## Headers vs Modules

If we would start a multiplatform app now and drop the XCFramwork into the app the linker would be able to link against our `libpjproject` and see the `_pj_init` symbol, for example. But Swift still can't see any of the symbols from PjSIP project.
In Xcode you could create a Bridging-Header and configure the include paths.

Since our goal is a neat Swift Package we create one for PjSIP project including the following:

```swift
.systemLibrary(name: "Cpjproject", pkgConfig: "pjproject-apple-platforms")
```

Pkg-config is a simple yet super-useful mechanism to configure the C/C++ compilers. If you have installed my final brew package for pjproject `brew install oliverepper/made/pjproject-apple-platforms` you can try it out by typing:

```sh
pkg-config --cflags --libs pjproject-apple-platforms
```
What you receive as output can be passed to a C/C++ compiler on the command-line. Let's make an example.

### Example program in ObjC
Create the program

```sh
cat << EOF > pjsip-test.m
#define PJ_AUTOCONF 1

#include <pjsua.h>

int main()
{
	pj_init();

	return 0;
}
EOF
```

compile it for macOS

```sh
clang -isysroot $(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk `pkg-config --libs --cflags pjproject-apple-platforms` -o pjsip-test pjsip-test.m
```

It should give you the following output:

```pre
08:40:15.580         os_core_unix.c !pjlib 2.12 for POSIX initialized
```

You can compile it for the iPhone simulator running on Apple Silicon like this:

```sh
clang -isysroot /Applications/Xcode-13.3.1.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk `pkg-config --libs --cflags pjproject-apple-platforms-iPhoneSimulator` -o pjsip-test pjsip-test.m
```

### SPM
Back to the `systemLibrary`-target we're still missing the translation between C-style header files and Swift modules. This can be achieved via the following `module.modulemap`:

```pre
module Cpjproject [system] {
    header "shim.h"
}

```

and the shim header:

```c
#define PJ_AUTOCONF 1
#include <pjsua.h>
```

### Wrapper or test target
Now we can create other targets in our swift package that can depend on `Cpjproject` and the will "see" all of pjproject from within Swift. All is great as long as we only build for the Mac!

## Other target
Once we try to build the swift package for other platforms (iPhoneOS, iPhoneSimulator) the pkg-config file configures the linker to load the version of `libpjproject.a` that was build for macOS which will then fail.

### The trick
I made another pkg-config file called `pjproject-apple-platforms-SPM` that intentionally gives no path to the libraries so using `-lpjproject` would fail.

```swift
.systemLibrary(name: "Cpjproject", pkgConfig: "pjproject-apple-platforms-SPM")
```

Swift package has another target type that can do the rescue, here:

```swift
.binaryTarget(name: "libpjproject", path: "libpjproject.xcframework")
```

A binary target understands XCFrameworks and copies the right libraries into place just before the build. This enables the linker to find the appropriate library for `-lpjproject`.

## Final
Finally create a third target:

```swift
.target(name: "PJSIP", dependencies: ["Cpjproject", "libpjproject"])
```

that you can use to give PjSIP project a nice swift interface. Something like `func pjInit() throws` and so on.

What we have achieved now ist that you can work on the swift package in isolation and have executable targets for integration tests, test targets for unit tests and once you use the swift package in a multiplatform app everything is automatically configured for you. Pretty neat :-D

### Links
- [brew package](https://github.com/oliverepper/homebrew-made)
- [demo App](https://github.com/oliverepper/pjproject-apple-platforms-Demo)