# Minimal FFmpeg (macOS) — Build & Use

This produces a **minimal FFmpeg** with just the components you asked for:

- **Screen/audio capture (indev):** `avfoundation` (select screen index)
- **Encoders:** `libx264`, `aac` (native)
- **Muxers:** `mp4`, `mov`, `matroska`
- **Filters:** `scale`, `overlay`, `drawtext`, `crop`
- **Protocols:** `file`, `pipe`

> For **internal audio** capture on macOS, install a virtual device such as **BlackHole** or **Loopback**, then select it through `avfoundation`.

## 1) Build

```bash
chmod +x build_macos_min_ffmpeg.sh
./build_macos_min_ffmpeg.sh
```

Artifacts will land in `./dist/bin/ffmpeg` and `./dist/bin/ffprobe`.

If you need a different FFmpeg tag, set `FFMPEG_TAG`, e.g.:

```bash
FFMPEG_TAG=n6.1 ./build_macos_min_ffmpeg.sh
```

## 2) Verify Features

```bash
./dist/bin/ffmpeg -hide_banner -filters | egrep "scale|overlay|drawtext|crop"
./dist/bin/ffmpeg -hide_banner -encoders | egrep "aac|libx264"
./dist/bin/ffmpeg -hide_banner -protocols | egrep "file|pipe"
./dist/bin/ffmpeg -hide_banner -muxers | egrep "mp4|mov|matroska"
./dist/bin/ffmpeg -f avfoundation -list_devices true -i ""
```

## 3) Record Examples

### List devices and indices
```bash
./dist/bin/ffmpeg -f avfoundation -list_devices true -i ""
```

### Record Display #1 with default mic, 30fps, H.264 + AAC to MP4
```bash
./dist/bin/ffmpeg \
  -f avfoundation -framerate 30 -i "1:0" \
  -c:v libx264 -preset fast -c:a aac \
  output.mp4
```

### Record Display #0 and mix in a BlackHole/Loopback device
Find the device index from `-list_devices` first, then:
```bash
./dist/bin/ffmpeg \
  -f avfoundation -framerate 30 -i "0:2" \
  -c:v libx264 -preset veryfast -c:a aac \
  out.mov
```

### Add filters
```bash
# Crop to 1920x1080 top-left and overlay a small logo at (20,20)
./dist/bin/ffmpeg -f avfoundation -framerate 30 -i "1:0" \
  -i logo.png -filter_complex "crop=1920:1080:0:0,scale=1920:1080[base];[base][1:v]overlay=20:20" \
  -c:v libx264 -c:a aac out.mp4

# Draw text (requires libfreetype)
./dist/bin/ffmpeg -f avfoundation -framerate 30 -i "1:0" \
  -vf "drawtext=fontfile=/System/Library/Fonts/Supplemental/Arial.ttf:text='Demo':x=10:y=10:fontsize=24:fontcolor=white" \
  -c:v libx264 -c:a aac out.mp4
```

## 4) Notes

- If you want a **universal2** binary (arm64 + x86_64), build twice on each arch (or use a cross toolchain) and `lipo -create` the two `ffmpeg` binaries.
- When using `--disable-everything`, we explicitly enable minimal “graph plumbing” filters (`buffer/buffersink/abuffer`, `format/aformat`, `null/anull`) to avoid common filter-graph errors.
- For fully **static** linking on macOS, expect friction with Homebrew libs and Apple frameworks; dynamic builds are typically simpler and reliable.
