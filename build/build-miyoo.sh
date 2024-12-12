#!/bin/sh
set -eu

TOOLCHAIN_IMAGE=docker.io/miyoocfw/toolchain-shared-musl:latest
docker run --rm -i -v $(pwd)/../src:/build ${TOOLCHAIN_IMAGE} /bin/bash <<EOF
set -eux
cd /build
/opt/miyoo/bin/arm-linux-gcc -std=c11 -Wall -Ofast -march=armv5te -mtune=arm926ej-s -fpic -shared -o gam4980_libretro.so libretro.c
EOF

