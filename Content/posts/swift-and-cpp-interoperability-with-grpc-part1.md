---
date: 2021-07-01 9:41
title: Swift and C++ interoperability with gRPC part 1
description: Let's (mis-)use gRPC to create Swift and C++ interoperability
tags: Swift, C++, SPM, CMake, xcframework, Xcode
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Prolog

This is going to be fun. I will show you how you can embed a gRPC server written in C++ in a Swift programm that you can run on a Mac or an iPhone. I'll use another gRPC server written in Swift so that not only the Swift part can call into C++ via gRPC but the C++ part can call into Swift via gRPC as well – all in the same process, of course :-D

## But why?

Well first it's **fun**, second you can learn a few things along the way and third: Given the right situation and constraints this can be a great idea!

## Warning

There're definitely a few other – more straight forward ways – of doing Swift/C++ interoperability; not all great though and with different trade offs. If you read through the end you know enough to decide wether or not this is for you.

*I do want to mention that Swift is – by far – the coolest programming language that I've came across and that it runs on Darwin, Linux and Windows and that you should really revistit your life choices if you manouvered yourself in the corner googleing for an article like this ;)*

## Start easy - create a demo library

Let's first create a little library in C++ that uses some random dependencies and cross-compile that for iPhone, iPhone simulators and the Mac running on Intel or Apple-Silicon. To enable multi-architectures we'll use fat-libs and to enable multi-platform support we'll stuff these fat-libs into a xcframework. All will be done via CMake, the [ios-cmake](https://github.com/leetal/ios-cmake) toolchain and a small shell script.

### chukle library

Start by creating a directory and a few files:

```bash
mkdir chuckle &&
touch chuckle/{chuckle.cpp,chuckle.h,Cli.cpp,CMakeLists.txt}
```

And add the following content:

#### chuckle.h

```C++
#ifndef CHUCKLE_CHUCKLE_H
#define CHUCKLE_CHUCKLE_H

#include <string>

std::string joke();

#endif //CHUCKLE_CHUCKLE_H
```

#### chuckle.cpp

```c++
#include "chuckle.h"
#include <cpr/cpr.h>
#include <nlohmann/json.hpp>

using namespace cpr;
using json = nlohmann::json;

std::string joke() {
    Response r = Get(Url("https://api.chucknorris.io/jokes/random"));
    json j = json::parse(r.text);

    return j["value"];
}
```

#### Cli.cpp

```c++
#include "chuckle.h"
#include <iostream>

using namespace std;

int main() {
    cout << joke() << endl;
    
    return 0;
}
```

and finally

#### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.19)
project(chuckle)

set(CMAKE_CXX_STANDARD 17)

set(CPR_BUILD_TESTS OFF)
set(CPR_BUILD_TESTS_SSL OFF)

include(FetchContent)
FetchContent_Declare(
        cpr
        GIT_REPOSITORY https://github.com/whoshuu/cpr.git
        GIT_TAG 1.6.2)
FetchContent_MakeAvailable(cpr)

FetchContent_Declare(json
        GIT_REPOSITORY https://github.com/nlohmann/json.git
        GIT_TAG v3.7.3)
FetchContent_GetProperties(json)
if(NOT json_POPULATED)
    FetchContent_Populate(json)
    add_subdirectory(${json_SOURCE_DIR} ${json_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

add_library(chuckle chuckle.cpp chuckle.h)
add_executable(joke Cli.cpp)

target_link_libraries(chuckle PRIVATE cpr::cpr nlohmann_json::nlohmann_json)
target_link_libraries(joke chuckle)
```

I am not a C++ programmer but I think the C++ code is quite readable. There's a free function `joke()` that returns a `std::string` representing a Joke – how usefull is that!

I used two dependencies for this great programm:

- [C++ Requests: Curl for People](https://github.com/whoshuu/cpr)
- [JSON for Modern C++](https://github.com/nlohmann/json)

If you never used CMake before – I didn't – let me point out a few things. `add_library` and `add_executable` add a target to the CMake project. `target_link_libraries` configures the linker to link build artefacts into products. In the above example you will end with the library `libchuckle` that we will use and a command line programm `joke` that you can run to test the library.

Both `FetchContent`-blocks are taken from the documentation from the two libraries that we use. Note that I configured the build of cpr by setting the two variables `CPR_BUILD_TESTS` and `CPR_BUILD_TESTS_SSL` to `OFF`.

We should be able to print a joke to the terminal, now. From inside the `chuckle` folder do the following:

```bash
mkdir out &&
cd out &&
cmake ..
```

This will download the dependencies and configure the build system. Once that's done you can build everything with:

```bash
make
```

and run the cli:

```bash
./joke
```

> Chuck Norris can mix water and oil.



Let's inspect what we have got so far:

- the `joke` programm  and
- `libchuckle.dylib`

Check the binary with `otool -L joke` you'll see something like this:

```
joke:
	@rpath/libchuckle.dylib (compatibility version 0.0.0, current version 0.0.0)
	@rpath/libcpr.1.dylib (compatibility version 1.0.0, current version 1.6.0)
	@rpath/libcurl-d.dylib (compatibility version 0.0.0, current version 0.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1775.118.101)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 59754.100.106)
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 905.6.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1292.100.5)
```

 That tells you that joke needs libchuckle.dylib to operate and that it doesn't really carry the meat from libchuckle in the binary. Check the size of the binary:

```bash
ls -lahs joke
```

It's 64k.

If you have [Hopper](https://www.hopperapp.com) – which I highly recommend – I want to show you something. Open the binary in Hopper and search for the label joke(). Click on the first occurence and then enable pseudo-code in Hopper:

```pseudocode
void _Z4jokev() {
    pointer to joke();
    return;
}
```

It's just a pointer. Not the real deal. `libchuckle.dylib` has it. Check if you want to :-D

#### build a static library

Building libchuckle as a static library is easy with CMake. Just add the STATIC keyword to the chuckle target:

```CMake
add_library(chuckle STATIC chuckle.cpp chuckle.h)
```

This time you might want to generate the build system in another folder:

```bash
mkdir static &&
cd static &&
cmake .. &&
make
```

Now `joke` is much larger (854 kb) and instead of `libchuckle.dylib` we have `libchuckle.a` a static library. If you open `joke` in Hopper again you'll see the following as pseudo-code for `joke()`:

```pse
int __Z4jokev() {
    r31 = r31 - 0x1d0;
    var_10 = r28;
    stack[-24] = r27;
    saved_fp = r29;
    stack[-8] = r30;
    r29 = &saved_fp;
    var_1A8 = r8;
    cpr::Url::Url(&stack[-384]);
    cpr::Response cpr::Get<cpr::Url>(&stack[-384]);
    cpr::Url::~Url();
    nlohmann::detail::input_adapter::input_adapter<std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, 0>(&stack[-432]);
    std::__1::function<bool (r29 - 0x38);
    nlohmann::basic_json<std::__1::map, std::__1::vector, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, bool, long long, unsigned long long, double, std::__1::allocator, nlohmann::adl_serializer>::parse(&stack[-432], r29 - 0x38, 0x1);
    std::__1::function<bool ();
    nlohmann::detail::input_adapter::~input_adapter();
    r0 = nlohmann::basic_json<std::__1::map, std::__1::vector, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, bool, long long, unsigned long long, double, std::__1::allocator, nlohmann::adl_serializer>& nlohmann::basic_json<std::__1::map, std::__1::vector, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, bool, long long, unsigned long long, double, std::__1::allocator, nlohmann::adl_serializer>::operator[]<char const>(&stack[-416]);
    var_1C0 = r0;
    nlohmann::basic_json<std::__1::map, std::__1::vector, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, bool, long long, unsigned long long, double, std::__1::allocator, nlohmann::adl_serializer>::operator std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> ><std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, 0>();
    var_18 = **___stack_chk_guard;
    nlohmann::basic_json<std::__1::map, std::__1::vector, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char> >, bool, long long, unsigned long long, double, std::__1::allocator, nlohmann::adl_serializer>::~basic_json();
    r0 = cpr::Response::~Response();
    r8 = *___stack_chk_guard;
    r8 = *r8;
    r8 = r8 - var_18;
    if (r8 != 0x0) {
            r0 = __stack_chk_fail();
    }
    return r0;
}
```

You can tell by the size of `libchuckle.a` (1,9Mb) that it should contain everything we need to proceed :-D

#### make it cross platform

To make this cross platform you need to change a few things. First you need to link alle the required object files into the libchuckle.a this can be done with CMake:

```Cmake
add_library(
        chuckle
        STATIC
        chuckle.cpp
        $<TARGET_OBJECTS:cpr>
        $<TARGET_OBJECTS:libcurl>
        $<TARGET_OBJECTS:zlib>
)
```

This links the object files into libchuckle. 

To build this for multiple architectures and platforms we need the [ios-cmake](https://github.com/leetal/ios-cmake) toolchain. Just copy it into the `chuckle` folder and while you're at it delete `static` and `out`.

You can now setup the build system for iOS devices with the following command:

```bash
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=OS64 \
            -DDEPLOYMENT_TARGET=14.0 \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/os64
```

If that step fails, please run it again. For [reasons](https://github.com/leetal/ios-cmake/issues/110) that I haven't understand yet this fails on the first run but works on the second run for me and others.

and run the build process with:

```bash
cmake --build ./out/os64 --config RelWithDebInfo
```

My complete build script looks like this:

```bash
#!/bin/sh

# iOS & simulator running on arm64 & x86_64
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=OS64 \
            -DDEPLOYMENT_TARGET=14.0 \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/os64
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=SIMULATORARM64 \
            -DDEPLOYMENT_TARGET=14.0 \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/simulator_arm64
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=SIMULATOR64 \
            -DDEPLOYMENT_TARGET=14.0 \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/simulator_x86_64

# macOS on arm64
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=MAC_ARM64 \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/mac_arm64

# macOS on x86_64
cmake -S ./ -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DPLATFORM=MAC \
            -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
            -DHAVE_SOCKET_LIBSOCKET=FALSE \
            -DHAVE_LIBSOCKET=FALSE \
            -B out/mac_x86_64

cmake --build ./out/os64 --config RelWithDebInfo --parallel 8
cmake --build ./out/simulator_arm64 --config RelWithDebInfo --parallel 8
cmake --build ./out/simulator_x86_64 --config RelWithDebInfo --parallel 8
cmake --build ./out/mac_arm64 --config RelWithDebInfo --parallel 8
cmake --build ./out/mac_x86_64 --config RelWithDebInfo --parallel 8

rm -rf libchuckle.xcframework

mkdir -p "out/mac/chuckle/"
mkdir -p "out/simulator/chuckle/"

lipo -create out/mac_arm64/chuckle/libchuckle.a \
             out/mac_x86_64/chuckle/libchuckle.a \
     -output out/mac/chuckle/libchuckle.a

lipo -create out/simulator_arm64/chuckle/libchuckle.a \
             out/simulator_x86_64/chuckle/libchuckle.a \
     -output out/simulator/chuckle/libchuckle.a

xcodebuild -create-xcframework \
  -library "out/os64/chuckle/libchuckle.a" \
  -library "out/simulator/chuckle/libchuckle.a" \
  -library "out/mac/chuckle/libchuckle.a" \
  -output libchuckle.xcframework

# copy Header
mkdir -p libchuckle.xcframework/Headers
cp include/chuckle/chuckle.h libchuckle.xcframework/Headers

# copy xcframework into Swift package
mkdir -p ChuckleWrapper/lib
cp -a libchuckle.xcframework ChuckleWrapper/lib
```

**CAUTION:** I changed a few locations. You can find the project here: [chuckle](https://github.com/oliverepper/chuckle)

Now we got a xframework that we can depend on in a Swift package that can carry an ObjC++-Wrapper to call into out code.
