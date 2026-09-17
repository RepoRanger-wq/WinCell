# WinCell

A native macOS menu bar app built with Swift, AppKit, and AVFoundation. Play a looping transparent video in the bottom-right corner of your desktop, with controls to start, stop, shuffle, or choose a clip.

## Features

- Random selection on each start, avoiding an immediate repeat.
- A thumbnail menu for choosing a specific clip.
- A transparent, click-through overlay above normal windows.
- Automatic stop timers, including custom durations and unlimited playback.
- Timer preservation when switching clips during a session.
- Three display sizes and optional sound, muted by default.
- Option–Command–F to toggle playback from another app.
- Local settings persistence; playback always starts off when the app launches.

## Build and run

Requires macOS 13 or later and Xcode command-line tools with a Swift compiler. The executable is built for the current Mac's architecture.

```sh
bash WinCell/build.sh
open "WinCell/build/WinCell.app"
```

The code builds without media. Supply your own videos locally and rebuild to enable playback. The app is signed locally for development; distribution to other Macs requires appropriate signing and notarization.

## Bring your own media

Create this local folder structure at the repository root:

```text
Finished Videos/
  My Clip/
    transparent.mov
    thumbnail.png
```

Use a MOV with an alpha channel, such as ProRes 4444. An opaque MP4 will not become transparent. The current overlay is sized for portrait 768 × 1168 clips. Folder names become picker labels.

The build copies only `transparent.mov` and `thumbnail.png` from this library into the app bundle. Set `WINCELL_VIDEO_DIR` to use another library directory. An optional original clip and thumbnail can be supplied through `WINCELL_ORIGINAL_VIDEO` and `WINCELL_ORIGINAL_THUMBNAIL`. These environment variables can also be set in an ignored `WinCell/build.local.sh` file. Relative paths are resolved from the `WinCell` directory.

No videos, thumbnails, media metadata, processing notes, screenshots, archives, or compiled apps are included in this repository. The ignore rules allow only the reviewed source and documentation files; all other local files are ignored by default. Locally built app bundles contain your supplied media, so do not publish those bundles if the media should remain private.

## Implementation

`WinCell/Sources/main.swift` contains the menu bar controls, video catalog, looping player, transparent window, timer, global shortcut, and playback checks. `WinCell/build.sh` compiles the executable and assembles the app bundle. The app does not use a server, analytics, or network services.

## Playback checks

After adding your own media and building, close the regular app and run:

```sh
"WinCell/build/WinCell.app/Contents/MacOS/WinCell" --smoke-test
```

The check exercises video decoding, playback progress, thumbnail loading, random and manual selection, automatic and manual stopping, and timer preservation when switching. It briefly displays each clip and exits. It requires local media and a logged-in macOS desktop session.
