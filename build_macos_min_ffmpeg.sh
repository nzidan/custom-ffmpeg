#!/usr/bin/env bash
set -euo pipefail

# Minimal FFmpeg for macOS with:
# - Screen/audio capture: avfoundation (selectable by index)
# - Encoders: libx264, aac (native)
# - Muxers: mp4, mov, matroska
# - Filters: scale, overlay, drawtext, crop (+ minimal graph plumbing)
# - Protocols: file, pipe
#
# Output layout:
#   ./dist/bin/ffmpeg (and ffprobe)
#
# Notes:
# - Requires Xcode Command Line Tools.
# - Uses Homebrew for toolchain and dependencies.
# - Builds a single-arch binary (the host arch). For a universal2 build, run twice and lipo.
#
# Usage:
#   chmod +x build_macos_min_ffmpeg.sh
#   ./build_macos_min_ffmpeg.sh
#
# Optional: set JOBS=8 to speed up.
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

ROOT_DIR="$(pwd)"
BUILD_DIR="${ROOT_DIR}/_build"
DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

echo "==> Checking prerequisites (Xcode CLT & Homebrew)"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found. Install them with: xcode-select --install"
  exit 1
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh and re-run."
  exit 1
fi

echo "==> Installing dependencies via Homebrew (may take a while)"
brew bundle --no-lock --file=- <<'BREWFILE'
tap "homebrew/core"
brew "pkg-config"
brew "nasm"
brew "cmake"
brew "libpng"
brew "freetype"
BREWFILE

# Resolve pkg-config paths (especially on Apple Silicon)
export PKG_CONFIG_PATH="$(brew --prefix)/lib/pkgconfig:$(brew --prefix libpng)/lib/pkgconfig:$(brew --prefix freetype)/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PATH="/usr/local/bin:/opt/homebrew/bin:${PATH}"

# Build x264 (libx264) from source with shared & static libs
echo "==> Building x264"
cd "${BUILD_DIR}"
if [ ! -d x264 ]; then
  git clone --depth 1 https://code.videolan.org/videolan/x264.git
fi
cd x264
# Configure x264 (shared is fine; static often trickier with Homebrew-provided libs)
./configure \
  --prefix="${DIST_DIR}" \
  --enable-pic \
  --enable-shared \
  --disable-cli
make -j"${JOBS}"
make install
hash -r

# Download FFmpeg release source
echo "==> Fetching FFmpeg source"
cd "${BUILD_DIR}"
FFMPEG_TAG="${FFMPEG_TAG:-n7.0}"  # change if you want a different release tag
if [ ! -d ffmpeg ]; then
  git clone --depth 1 -b "${FFMPEG_TAG}" https://github.com/FFmpeg/FFmpeg.git ffmpeg
fi

cd ffmpeg

# Configure minimal FFmpeg
# Important: when using --disable-everything, you must explicitly enable each needed component.
# drawtext requires libfreetype.
# avfoundation is an input device (indev) on macOS.
# Add a few "graph plumbing" filters (buffer/buffersink/format/aformat/null/anull) to avoid common pipeline errors.
echo "==> Configuring FFmpeg (minimal feature set)"
./configure \
  --prefix="${DIST_DIR}" \
  --disable-debug \
  --disable-doc \
  --disable-programs \
  --enable-ffmpeg \
  --enable-ffprobe \
  --disable-everything \
  --enable-indev=avfoundation \
  --enable-protocol=file \
  --enable-protocol=pipe \
  --enable-muxer=mp4 \
  --enable-muxer=mov \
  --enable-muxer=matroska \
  --enable-encoder=libx264 \
  --enable-encoder=aac \
  --enable-filter=scale \
  --enable-filter=overlay \
  --enable-filter=drawtext \
  --enable-filter=crop \
  --enable-filter=buffer \
  --enable-filter=buffersink \
  --enable-filter=abuffer \
  --enable-filter=format \
  --enable-filter=aformat \
  --enable-filter=null \
  --enable-filter=anull \
  --enable-gpl \
  --enable-libx264 \
  --enable-libfreetype

echo "==> Building FFmpeg"
make -j"${JOBS}"
make install

echo "==> Finished. Binaries are in: ${DIST_DIR}/bin"
"${DIST_DIR}/bin/ffmpeg" -hide_banner -filters | grep -E "scale|overlay|drawtext|crop" || true
echo "Try: ${DIST_DIR}/bin/ffmpeg -f avfoundation -list_devices true -i \"\""
echo "Then record: ${DIST_DIR}/bin/ffmpeg -f avfoundation -framerate 30 -i \"1:0\" -c:v libx264 -preset fast -c:a aac out.mp4"
