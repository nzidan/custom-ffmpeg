# Minimal FFmpeg (Static) — Windows & macOS CI builds

This repo layout covers your requirements exactly:

- **x264 static build**
  ```sh
  cd x264
  ./configure --enable-static --disable-cli --disable-opencl --prefix=$PWD
  make && make install
  export PKG_CONFIG_PATH=$PWD
  ```

- **FFmpeg static build**
  ```sh
  # macOS note: add --extra-ldflags="-framework CoreAudio"
  ./configure --enable-static --enable-gpl --enable-libx264 \
    --disable-ffplay --disable-ffprobe --disable-sdl2 \
    --disable-bzlib --disable-iconv --disable-zlib --disable-lzma
  ```

- **Patching**
  - Windows: `git apply ../ffmpeg_patches/win/removed_captureblt_from_gdigrab.patch`
  - macOS:
    ```sh
    cp ../ffmpeg_patches/darwin/include/* ./libavdevice
    git apply ../ffmpeg_patches/darwin/*.patch
    ```

Both workflows also **enable your required components**:
- Capture: `gdigrab` + `dshow` (Windows), `avfoundation` (macOS)
- Encoders: `libx264`, `aac`
- Muxers: `mp4`, `mov`, `matroska`
- Filters: `scale`, `overlay`, `drawtext`, `crop` (+ minimal plumbing)
- Protocols: `file`, `pipe`

## Usage

1. Put the two workflow files into `.github/workflows/` in your repo.
2. Place your actual patches into `ffmpeg_patches/win/` and `ffmpeg_patches/darwin/` (replace the placeholders).
3. Go to **GitHub Actions** and run the workflows manually, or push to `main`.
4. Download artifacts:
   - **Windows:** `ffmpeg-windows-static-minimal`
   - **macOS:** `ffmpeg-macos-static-minimal`

> Tip: If you need a different FFmpeg version, set `FFMPEG_TAG` when dispatching the workflow or add `env:` to the jobs.
