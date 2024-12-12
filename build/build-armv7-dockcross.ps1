# 构建 armv7 cortex-a53 的文件

$SrcPath = Join-Path $(Get-Location) '../src/'
docker run --rm -v ${SrcPath}:/work dockcross/linux-armv7 bash -c '$CC -std=c11 -Wall -Ofast -march=armv7 -mtune=cortex-a53 -fpic -shared -DSWAP_LCD_WIDTH_HEIGHT -o gam4980_libretro.so libretro.c'