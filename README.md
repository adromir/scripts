# Scripts & Automation Utilities (PowerShell, Bash, Python, Userscripts)

The `scripts` repository contains automation tools, desktop utilities, and scripts categorized across four primary subfolders: `powershell`, `bash`, `python`, and `userscripts`.

## `scripts/powershell/`

This folder contains further subdirectories for PowerShell scripts, categorized by function:

### `video/`
Contains scripts for video manipulation.

* **`convert-mov-to-mp4/`**:
    * Contains: `Convert-MOVtoMP4.ps1`
    * Summary: Provides a GUI to convert `.mov` files to `.mp4` using `ffmpeg`, supporting GPU acceleration and quality presets.
* **`reencode-mp4/`**:
    * Contains: `reencode-mp4.ps1`
    * Summary: Provides a GUI to re-encode `.mp4` files using `ffmpeg`, offering options for quality/bitrate, hardware acceleration (NVENC, QSV, AMF), and optional overwriting.

### `gpx/`
Contains scripts for handling GPX files.

* **`gpx-clean/`**:
    * Contains: `gpx-clean.ps1`
    * Summary: Provides a GUI script to clean GPX files by filtering points based on coordinate prefixes and generates analysis/SQL queries.
* **`gpx-info/`**:
    * Contains: `gpx-info.ps1`
    * Summary: Parses GPX files to extract waypoint/trackpoint counts, find first/last timestamps, and generate a sample PostgreSQL query.

### `exif/`
Contains scripts for managing EXIF metadata.

* **`check-metadata/`**:
    * Contains: `Check-Metadata.ps1`
    * Summary: Provides a GUI to scan folders for media files and check for metadata errors/warnings using ExifTool, displaying results in a WPF window.
* **`cleanxmp/`**:
    * Contains: `CleanXMP.ps1`
    * Summary: Recursively finds `.xmp` files and removes all occurrences of "st|" (or a configured string) from their content.
* **`fix-metadata/`**:
    * Contains: `fix-metadata.ps1`
    * Summary: Provides a GUI script that either parses an ExifTool error log or scans a folder to validate images and attempts to fix identified metadata errors using specific ExifTool commands.
* **`geotag/`**:
    * Contains: `config.json`, `geotag_media.ps1`
    * Summary: Provides a GUI script to add/update GPS and location metadata to image and MP4 files by querying Dawarich and Photon APIs based on creation time.
* **`mp4_date_metadata/`**:
    * Contains: `mp4_add_missing_date.ps1`
    * Summary: Provides a GUI script to add or overwrite `CreateDate`, `MediaCreateDate`, and `TrackCreateDate` in MP4 files using ExifTool, primarily for Windows Explorer compatibility (overwrites originals).
* **`update-previews/`**:
    * Contains: `update-previews.ps1`
    * Summary: Provides a GUI to update embedded previews from RAW files using Adobe DNG Converter for DNG Files or ExifTool + Imagemagick + DCRAW for any other Raw-File Format.
* **`rotate/`**:
    * Contains: `exif-rotate.ps1`
    * Summary: Provides a WPF GUI script to visually rotate images based on EXIF orientation using ExifTool, allowing interactive rotation and saving changes to metadata.
* **`update_date/`**:
    * Contains: `exif_date_update.ps1`
    * Summary: Updates missing EXIF dates (`DateTimeOriginal`, `CreateDate`) in images (JPG, DNG, CR2) by parsing filenames like `IMG_YYYYMMDD_HHMMSS[_TAG].ext` and updates file system timestamps.
* **`create-xmp/`**:
    * Contains: `create-xmp.ps1`
    * Summary: Runs through all Media files in a selected folder (with option to include subfolders) and creates corresponding XMP sidecar files.

### `misc/`
Contains miscellaneous utilities and benchmarking tools.

* **`llama-bench/`**:
    * Contains: `llama.bench.ps1`
    * Summary: Modern WPF GUI benchmark suite for `llama.cpp` builds (`llama-cli.exe`), featuring multi-build comparative testing, EN/DE localization, standardized scenarios, and offline interactive Chart.js HTML reports.
* **`ventoy_boot/`**:
    * Contains: `VentoyLocalBootEditor.ps1`, `MainWindow.xaml`, `lang/de.json`, `lang/en.json`
    * Summary: Standalone WPF GUI configurator to manage local disk boot entries (`ventoy_grub.cfg`), raw boot-sector UUID detection, multi-OS chainloaders, and global Ventoy settings (`ventoy.json`).

### `music/`
Contains scripts for audio processing and soundscape archiving.

* **`ambient-mixer/`**:
    * Contains: `ambient-mixer-download.ps1`, `config.json`
    * Summary: WPF GUI script to download complete ambient sound mixes (XML configuration, audio tracks, and cover image) from ambient-mixer.com for offline playback.

### `postgres/`
Contains database management and migration tools.

* **`migrate/`**:
    * Contains: `pg_migrate_pro.ps1`, `MainWindow.xaml`, `config.json`, `lang/`
    * Summary: Professional, asynchronous WPF GUI tool for PostgreSQL and MySQL migrations, backups, and restores with DPAPI encrypted credential storage, multi-language support, and automated tool downloading.

## `scripts/bash/`

This folder contains further subdirectories for Bash scripts:

### `docker/`
Contains scripts for Docker container management.

* **`auto-compose/`**:
    * Contains: `auto-compose.sh`
    * Summary: Inspects running Docker containers and generates clean, standalone `docker-compose.yml` (v3.8) files with filtered environment variables, mount points, and static external networks.

### `exif/`
Contains scripts for managing EXIF metadata using Bash.

* **`geocode/`**:
    * Contains: `geotag_media.sh`
    * Summary: Provides a `zenity` GUI script to add/update GPS and location metadata to images (in file or sidecar) and MP4s (in XMP sidecar) by querying Dawarich and Photon APIs.

### `immich/`
Contains scripts related to Immich photo management.

* **`un-stacker/`**:
    * Contains: `immich-stacker.sh`, `immich-unstacker.sh`
    * Summary: Contains two scripts (`immich-stacker.sh`, `immich-unstacker.sh`) that use the Immich API to automatically stack related assets based on filename patterns or unstack all existing asset stacks.

## `scripts/python/`

This folder contains standalone Python desktop and media applications:

### `ambient-player/`
Contains media playback tools for multi-track ambient audio.

* **`ambient-player/`**:
    * Contains: `ambient.player.py`, `player_ui.qml`, `player_settings.conf`
    * Summary: Modern PySide6 (Qt Quick / QML Material Dark) and Pygame multi-channel ambient sound player designed to load and play XML presets downloaded via the Ambient Mixer Downloader script.

## `scripts/userscripts/`

This folder contains further subdirectories for Userscripts (which can be used by Browser Extensions like Tampermonkey), categorized by function: 

### `gemini-snippets/`

* **`gemini-snippets/`**:
    * Contains: `google_gemini_mod.user.js`, `gemini_mod_drive.js`, `gemini_mod_styles.js`, `gemini_mod_utils.js`
    * Summary: Modular browser userscript for gemini.google.com providing a freely customizable toolbar to manage, insert, and sync custom prompt snippets via Google Drive.
