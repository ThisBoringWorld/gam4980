# 构建指定架构的文件

[CmdletBinding()]
param(
	[ValidateSet(
		'android-arm', 'android-arm64', 'android-x86', 'android-x86_64',
		'linux-arm64', 'linux-arm64-lts', 'linux-arm64-full', 'linux-arm64-musl',
		'linux-armv5', 'linux-armv5-musl', 'linux-armv5-uclibc', 'linux-armv6',
		'linux-armv6-lts', 'linux-armv6-musl', 'linux-armv7', 'linux-armv7-lts',
		'linux-armv7a', 'linux-armv7l-musl', 'linux-loongarch64', 'linux-mips',
		'linux-mips-uclibc', 'linux-mips-lts', 'linux-mipsel-lts', 'linux-s390x',
		'linux-ppc', 'linux-ppc64le', 'linux-ppc64le-lts', 'linux-riscv32',
		'linux-riscv64', 'linux-m68k-uclibc', 'linux-xtensa-uclibc',
		'manylinux_2_28-x64', 'manylinux_2_28-aarch64', 'manylinux_2_34-x64',
		'manylinux_2_34-aarch64', 'manylinux2014-x86', 'manylinux2014-x64',
		'linux-i686', 'linux-x86', 'linux-x64', 'linux-x86_64-full',
		'linux-x64-clang', 'linux-x64-tinycc', 'web-wasm', 'web-wasi',
		'web-wasi-threads', 'windows-shared-x86', 'windows-shared-x64',
		'windows-shared-x64-posix', 'windows-static-x86', 'windows-static-x64',
		'windows-static-x64-posix', 'windows-armv7', 'windows-arm64'
	)]
	[string]$TargetArch = 'android-arm64'
)

$TargetSpec = @{
	'android-arm' = @{ March = '-march=ARMv7'; Mtune = '-mtune=generic'; Defines = '' }
	'android-arm64' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'android-x86' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'android-x86_64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-arm64' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-arm64-lts' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-arm64-full' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-arm64-musl' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-armv5' = @{ March = '-march=armv5te'; Mtune = '-mtune=arm926ej-s'; Defines = '' }
	'linux-armv5-musl' = @{ March = '-march=armv5te'; Mtune = '-mtune=arm926ej-s'; Defines = '' }
	'linux-armv5-uclibc' = @{ March = '-march=armv5te'; Mtune = '-mtune=arm926ej-s'; Defines = '' }
	'linux-armv6' = @{ March = '-march=armv6'; Mtune = '-mtune=arm1176jzf-s'; Defines = '' }
	'linux-armv6-lts' = @{ March = '-march=armv6'; Mtune = '-mtune=arm1176jzf-s'; Defines = '' }
	'linux-armv6-musl' = @{ March = '-march=armv6'; Mtune = '-mtune=arm1176jzf-s'; Defines = '' }
	'linux-armv7' = @{ March = '-march=armv7'; Mtune = '-mtune=cortex-a53'; Defines = '-DSWAP_LCD_WIDTH_HEIGHT' }
	'linux-armv7-lts' = @{ March = '-march=armv7'; Mtune = '-mtune=cortex-a53'; Defines = '-DSWAP_LCD_WIDTH_HEIGHT' }
	'linux-armv7a' = @{ March = '-march=armv7-a'; Mtune = '-mtune=cortex-a53'; Defines = '-DSWAP_LCD_WIDTH_HEIGHT' }
	'linux-armv7l-musl' = @{ March = '-march=armv7'; Mtune = '-mtune=cortex-a53'; Defines = '-DSWAP_LCD_WIDTH_HEIGHT' }
	'linux-loongarch64' = @{ March = '-march=loongarch64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-mips' = @{ March = '-march=mips32'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-mips-uclibc' = @{ March = '-march=mips32'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-mips-lts' = @{ March = '-march=mips32'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-mipsel-lts' = @{ March = '-march=mips32'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-s390x' = @{ March = '-march=z196'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-ppc' = @{ March = '-march=powerpc'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-ppc64le' = @{ March = '-march=power8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-ppc64le-lts' = @{ March = '-march=power8'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-riscv32' = @{ March = '-march=rv32imafdc'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-riscv64' = @{ March = '-march=rv64imafdc'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-m68k-uclibc' = @{ March = '-march=m68k'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-xtensa-uclibc' = @{ March = '-march=xtensa'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux_2_28-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux_2_28-aarch64' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux_2_34-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux_2_34-aarch64' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux2014-x86' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'manylinux2014-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-i686' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-x86' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-x86_64-full' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-x64-clang' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'linux-x64-tinycc' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'web-wasm' = @{ March = ''; Mtune = ''; Defines = '' }
	'web-wasi' = @{ March = ''; Mtune = ''; Defines = '' }
	'web-wasi-threads' = @{ March = ''; Mtune = ''; Defines = '' }
	'windows-shared-x86' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-shared-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-shared-x64-posix' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-static-x86' = @{ March = '-march=i686'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-static-x64' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-static-x64-posix' = @{ March = '-march=x86-64'; Mtune = '-mtune=generic'; Defines = '' }
	'windows-armv7' = @{ March = '-march=armv7'; Mtune = '-mtune=cortex-a53'; Defines = '' }
	'windows-arm64' = @{ March = '-march=ARMv8'; Mtune = '-mtune=generic'; Defines = '' }
}

if (-not $TargetSpec.ContainsKey($TargetArch)) {
	throw "不支持的目标架构: $TargetArch"
}

$Spec = $TargetSpec[$TargetArch]
$SrcPath = Join-Path $PSScriptRoot '..\src'
$CompileArgs = @('$CC', '-std=c11', '-Wall', '-Ofast')
if ($Spec.March) { $CompileArgs += $Spec.March }
if ($Spec.Mtune) { $CompileArgs += $Spec.Mtune }
if ($Spec.Defines) { $CompileArgs += $Spec.Defines }
$CompileArgs += @('-fpic', '-shared', '-o', 'gam4980_libretro.so', 'libretro.c')

docker run --rm -v ${SrcPath}:/work "dockcross/$TargetArch" bash -c "$($CompileArgs -join ' ')"
