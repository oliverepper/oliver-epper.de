#!/bin/sh

ssh-add -T ~/.ssh/id_rsa.pub &&
export PYTHON_LIBRARY=/opt/homebrew/Cellar/python@3.11/3.11.2_1/Frameworks/Python.framework/Versions/3.11/lib/libpython3.11.dylib
publish generate &&
rsync -a Output/* oliver@shiny:~/oliver-epper.de/html/ &&
rsync -a Output/* oliver@one:~/oliver-epper.de/html/ &&
publish deploy
