#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	fontconfig \
	fribidi \
	gamemode \
	libdecor \
	libpipewire \
	libxinerama \
	libxkbcommon \
	libxv \
	qt6-base \
	sdl2 \
	v4l-utils \
	vulkan-icd-loader \
	wayland-protocols

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano ffmpeg-mini

echo "Fetching RetroArch source..."
echo "---------------------------------------------------------------"
URL=$(curl -sL https://api.github.com/repos/libretro/RetroArch/releases/latest | \
	jq -r '.assets[] | select(.name | startswith("retroarch-sourceonly-") and endswith(".tar.xz")) | .browser_download_url')

[ -n "$URL" ] || { echo "ERROR: no se encontró el asset del release"; exit 1; }

wget "$URL" -O ra.tar.xz

SRCDIR=$(tar -tf ra.tar.xz | head -n1 | cut -d/ -f1)
tar -xf ra.tar.xz
cd "$SRCDIR"

echo "Applying ffmpeg-9 compatibility patch..."
echo "---------------------------------------------------------------"
wget https://gitlab.archlinux.org/archlinux/packaging/packages/retroarch/-/raw/main/ffmpeg-9.patch -O /tmp/ffmpeg-9.patch
patch -Np1 -i /tmp/ffmpeg-9.patch

echo "Building RetroArch..."
echo "---------------------------------------------------------------"
./configure \
	--prefix=/usr \
	--enable-builtinmbedtls \
	--disable-builtinzlib \
	--disable-cg \
	--disable-jack \
	--disable-oss \
	--disable-sdl \
	--enable-dbus

make -j"$(nproc)"
make -C libretro-common/audio/dsp_filters
make -C gfx/video_filters

echo "Installing RetroArch globally..."
echo "---------------------------------------------------------------"
make DESTDIR=/ install
install -Dm 644 libretro-common/audio/dsp_filters/*.{dsp,so} -t /usr/lib/retroarch/filters/audio/
install -Dm 644 gfx/video_filters/*.{filt,so} -t /usr/lib/retroarch/filters/video/

echo "Saving version for the AppImage script..."
echo "---------------------------------------------------------------"
curl -sL https://api.github.com/repos/libretro/RetroArch/releases/latest | \
	jq -r '.tag_name' | sed 's/^v//' > ~/version
