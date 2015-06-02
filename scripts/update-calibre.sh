#!/bin/bash -e

# Make sure only root can run our script
if [[ $EUID -ne 0 ]] ; then
   echo "This script must be run as root" 2>&1
   exit 1
fi

SRC=https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py

wget -nv -O- $SRC | python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main()"
