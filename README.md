# WinCell

A native macOS menu bar app built with Swift, AppKit, and AVFoundation. Play a looping transparent video in the bottom-right corner of your desktop, with controls to start, stop, shuffle, or choose a clip.

## Features

- Random selection on each start, avoiding an immediate repeat.
- A thumbnail menu for choosing a specific clip.
- A local video library that refreshes when you open the menu, with no rebuild needed.
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

The code builds without media. Add your own videos to the local library to enable playback. No rebuild is needed when adding or removing clips. The app is signed locally for development; distribution to other Macs requires appropriate signing and notarization.

## Bring your own media

1. Launch WinCell and click its sparkle icon in the menu bar.
2. Choose **Open Video Folder…**. WinCell creates and opens `~/Movies/WinCell/` for the current user.
3. Add one subfolder per clip, as shown below.
4. Open the menu again (or choose **Refresh Videos**). Select a clip under **Choose Video**, or use **Play Random Video**.

```text
~/Movies/WinCell/
  My First Clip/
    video.mov
    thumbnail.png
  Another Clip/
    animation.mp4
```

Each clip folder needs one `.mov`, `.mp4`, or `.m4v` file supported by macOS. The filename can be anything; the folder name becomes the menu label. If there are several video files in one folder, WinCell prefers `video.mov`, then `transparent.mov`, then the first filename in natural alphabetical order. Use separate folders for separately selectable clips. Loose files in the library root and hidden folders are ignored.

A thumbnail is optional. Name it `thumbnail.png`, `thumbnail.jpg`, or `thumbnail.jpeg`; otherwise the menu uses a film icon. Invalid or incomplete clip folders are skipped. If the folder is inaccessible, the menu reports the problem. An empty library offers instructions for adding clips. Unsupported or corrupt videos stop with an error message.

For transparency, use a video with an alpha channel, such as ProRes 4444 or HEVC with alpha. Opaque videos still play with their background intact. WinCell fits portrait, landscape, and square videos in the bottom-right corner while preserving their proportions and respecting the Dock.

The library is outside both the repository and the app, so moving or rebuilding the app does not change your clips. Adding and removing clips is picked up whenever the menu opens; refreshing stops playback if its file has been removed. New clips do not automatically start playing until you choose Play or select one. There are no machine-specific source paths or bundled videos.

For testing or launching with a different library, set `WINCELL_LIBRARY_DIR` to a directory when running the executable directly:

```sh
WINCELL_LIBRARY_DIR="/path/to/my/library" "WinCell/build/WinCell.app/Contents/MacOS/WinCell"
```

### Privacy

Media stays on your Mac. No videos, thumbnails, media metadata, processing notes, screenshots, archives, or compiled apps are included in this repository. The ignore rules allow only the reviewed source and documentation files; all other local files are ignored by default. Builds contain no media and do not read machine-local build configuration.

### Upgrading from bundled videos

Copy each existing clip into the library structure above before rebuilding. The previous `transparent.mov` filename is supported, so existing clip folders work as-is. The new build removes old media from the generated app bundle; keep your source videos outside the app. The former build-time media environment variables and `build.local.sh` are no longer used.

## Implementation

`WinCell/Sources/main.swift` contains the menu bar controls, video catalog, looping player, transparent window, timer, global shortcut, and playback checks. `WinCell/build.sh` compiles the executable and assembles the app bundle. The app does not use a server, analytics, or network services.

## Playback checks

For library discovery checks without media, run:

```sh
"WinCell/build/WinCell.app/Contents/MacOS/WinCell" --library-test
```

For playback checks, add your own media to the library, close the regular app, and run:

```sh
"WinCell/build/WinCell.app/Contents/MacOS/WinCell" --smoke-test
```

The check exercises video decoding, playback progress, thumbnail loading, random and manual selection, automatic and manual stopping, and timer preservation when switching. It briefly displays each clip and exits. It requires local media and a logged-in macOS desktop session.
