#!/bin/sh

ssh-add -T ~/.ssh/id_rsa.pub &&
publish generate &&
rsync -a Output/* oliver@shiny:~/oliver-epper.de/html/ &&
publish deploy