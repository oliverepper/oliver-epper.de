---
date: 2021-10-07 9:41
title: Using private API
description: Find and use API that is private
tags: Swift, Hopper
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## The idea

I needed a little tool that could show me which app has registered a certain URL on my Mac. Since the ouput of `lsregister -dump` is not quite eyecandy I decided to hack together a minimal tool that could do two things:

- show me a list of all registered URLs and their handlers
- be able to unregister a handler

Unfortunatley the public API of LaunchServices doesn't help with any of these.

## The resuce

Well `lsregister` can unregister apps so it's time to drop it into [Hopper](https://www.hopperapp.com) and start digging around. Often times this is way easier than you think. Drop lsregister into Hopper and search for unregister. You'll find a symbol `_LSUnregisterURL` immediately. If you don't have Hopper available you can use `nm lsregister | grep register`.



## The trick

[Helge Heß](https://www.helgehess.eu) pointed me to a nice way of making a private function available in Swift. Basically you can load a symbol with `dlsym` and then cast it to a type that has C calling convention. 

```Swift
private let handle = dlopen(nil, RTLD_NOW)
private let fnUnregister = dlsym(handle, "_LSUnregisterURL")
typealias fnUnregisterType = @convention(c) (CFURL) -> OSStatus

// now you can cast
let LSUnregisterURL = unsafeBitCast(fnUnregister, to: fnUnregisterType.self)

// and call the function
let result = LSUnregisterURL(url as CFURL)
```



## The constraints

Actually you cannot run this function out of a sandbox. The obvious choice for such a tool would be to just disable the sandbox but hey: Why not wrap it in an XPCService?



## The tool

If you want to check out the tool or find it useful yourself you can find it here: [Schemes](https://oliver-epper.de/apps/schemes/). Source available here: [Scheme Source](https://github.com/oliverepper/Schemes).
