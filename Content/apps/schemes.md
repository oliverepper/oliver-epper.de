---
date: 2021-10-05 9:41
title: Schemes
description: List & edit schemes and handlers on MacOS
tags: macOS, AppKit, Tools
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

Schemes lists all the schemes and their handlers that are registered via Launch Services on your system.

![Schemes](/images/Schemes.png)

Unregistering an entry removes that app from launch services. You could do this manually by using `lsregister`.
Example:
```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u /path/to/your.app
```

[Download Schemes v0.3.1](https://oliver-epper.de/Schemes/Schemes-0.3.1.zip)

[Sources](https://github.com/oliverepper/Schemes)

