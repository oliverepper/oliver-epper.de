#!/bin/sh

ssh-add -T ~/.ssh/id_rsa.pub &&
export PYTHON_LIBRARY=/opt/homebrew/Cellar/python@3.10/3.10.14_1/Frameworks/Python.framework/Versions/3.10/lib/libpython3.10.dylib
publish generate
rsync -a Output/* oliver@shiny:~/oliver-epper.de/html/ &&
rsync -a Output/* oliver@one:~/oliver-epper.de/html/ &&
publish deploy
