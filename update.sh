#!/bin/sh

ssh-add -T ~/.ssh/id_rsa.pub &&
export PYTHON_LIBRARY=/Applications/Xcode-13.4.1.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/Current/lib/libpython3.8.dylib
publish generate &&
rsync -a Output/* oliver@shiny:~/oliver-epper.de/html/ &&
publish deploy
