#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
case "$PWD" in
    *:*) exec python3 zLoader/scripts/build-in-cache.py sh zLoader/scripts/test-install-acknowledgement.sh ;;
esac
sh zLoader/scripts/prepare-patched-idevice.sh test
