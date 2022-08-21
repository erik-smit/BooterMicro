#!/bin/bash
#
# PROG: No longer making .img files, just unzippin!
#

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )" 

if [ -z "$1" ]; then
  echo "Usage: $0 pathtozip"
  exit
fi

ZIPNAME="$1"
DIRNAME="`dirname \"$ZIPNAME\"`/`basename \"$ZIPNAME\" .zip`"

# Unzip the downloaded .zip in its proper directory, nothing fancy to see here.
unzip -jo $ZIPNAME -d$DIRNAME

#replaced 7z with unzip after unpredictable behavior surrounding directories/files named identically to directories in SM releases.
#7z x $ZIPNAME -o$DIRNAME


