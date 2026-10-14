#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	dav1d             \
	fontconfig        \
	fribidi           \
	gamemode          \
	libdecor          \
	libpipewire       \
	libvpx            \
	libxinerama       \
	libxkbcommon      \
	libxv             \
	nasm              \
	sdl2              \
	v4l-utils         \
	wayland-protocols \
	x264

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
echo "Building static ffmpeg..."
echo "---------------------------------------------------------------"
FFMPEG_VER=9.0.2
git clone --branch "n$FFMPEG_VER" --single-branch --depth 1 https://github.com/FFmpeg/FFmpeg.git ./ffmpeg && (
	cd ./ffmpeg

	# RetroArch only uses ffmpeg to record, to play content and for its camera
	# driver, so avfilter, the network stack and the optional dependencies that
	# pull in most of the size are not needed
	./configure                 \
		--prefix=/usr/local     \
		--enable-static         \
		--disable-shared        \
		--enable-pic            \
		--enable-small          \
		--enable-gpl            \
		--enable-zlib           \
		--disable-autodetect    \
		--disable-programs      \
		--disable-doc           \
		--disable-network       \
		--disable-avfilter      \
		--enable-libdav1d       \
		--enable-libopus        \
		--enable-libvpx         \
		--enable-libx264

	make -j"$(nproc)"
	make install
)

echo "Building RetroArch..."
echo "---------------------------------------------------------------"
REPO="https://github.com/libretro/RetroArch"
VERSION="$(git ls-remote --tags --sort="v:refname" "$REPO" | grep -v '\^{}' | tail -n1 | sed 's/.*\///; s/^v//')"
git clone --branch "v$VERSION" --single-branch --depth 1 "$REPO" ./RetroArch && (
	cd ./RetroArch
	echo "$VERSION" > ~/version

	# RetroArch 1.22.2 does not build against ffmpeg 9
	wget -q https://gitlab.archlinux.org/archlinux/packaging/packages/retroarch/-/raw/main/ffmpeg-9.patch -O ./ffmpeg-9.patch
	patch -Np1 -i ./ffmpeg-9.patch

	# link the static ffmpeg built above
	export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

	./configure                   \
		--prefix=/usr             \
		--enable-builtinmbedtls   \
		--disable-builtinzlib     \
		--disable-cg              \
		--disable-jack            \
		--disable-oss             \
		--disable-sdl             \
		--enable-dbus             \
		--disable-debug           \
		--disable-qt

	make -j"$(nproc)"
	make -C libretro-common/audio/dsp_filters
	make -C gfx/video_filters
	make install

	# the DSP and video filters are not part of the make install target
	mkdir -p /usr/lib/retroarch/filters/audio /usr/lib/retroarch/filters/video
	cp -v libretro-common/audio/dsp_filters/*.dsp libretro-common/audio/dsp_filters/*.so /usr/lib/retroarch/filters/audio/
	cp -v gfx/video_filters/*.filt gfx/video_filters/*.so /usr/lib/retroarch/filters/video/
)
