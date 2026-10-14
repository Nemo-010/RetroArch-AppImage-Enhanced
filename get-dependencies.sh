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
	libva             \
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
# ffmpeg 9 removed AVCodec.sample_fmts and supported_samplerates, which
# RetroArch 1.22.2 still reads, so stick to the latest 8.x
FFMPEG_VER=8.1.3
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
		--enable-libdrm         \
		--enable-libopus        \
		--enable-libvpx         \
		--enable-libx264        \
		--enable-vaapi

	make -j"$(nproc)"
	make install
)

echo "Building RetroArch..."
echo "---------------------------------------------------------------"
git clone https://github.com/libretro/RetroArch ./RetroArch && (
	cd ./RetroArch

	git fetch --tags origin
	TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha\|beta\|nightly' | head -1)
	git checkout "$TAG"
	echo "${TAG#v}" > ~/version

	# resolve the data dirs relative to the binary instead of the hardcoded
	# /usr/share prefix
	patch -Np1 -i ../retroarch-relocatable.patch

	# link the static ffmpeg built above
	export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

	# Point the global config dir at the AppDir, a distro /etc/retroarch.cfg
	# would otherwise be used as the skeleton for a new user config
	./configure                        \
		--prefix=/usr                  \
		--sysconfdir=/usr/share/retroarch \
		--enable-builtinmbedtls        \
		--disable-builtinzlib          \
		--disable-cg                   \
		--disable-jack                 \
		--disable-oss                  \
		--disable-sdl                  \
		--enable-dbus                  \
		--disable-debug                \
		--disable-discord              \
		--disable-qt

	make -j"$(nproc)"
	make -C ./libretro-common/audio/dsp_filters
	make -C ./gfx/video_filters
	make install

	# the skeleton config is a distro thing, without it RetroArch builds the
	# first run config from its compiled in defaults
	rm -f /usr/share/retroarch/retroarch.cfg

	# the DSP and video filters are not part of the make install target
	mkdir -p /usr/share/retroarch/filters/audio /usr/share/retroarch/filters/video
	cp -v ./libretro-common/audio/dsp_filters/*.dsp ./libretro-common/audio/dsp_filters/*.so /usr/share/retroarch/filters/audio/
	cp -v ./gfx/video_filters/*.filt ./gfx/video_filters/*.so /usr/share/retroarch/filters/video/
)
