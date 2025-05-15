# Scripts (Bash and Powershell)

The `scripts` folder contains two main subfolders: `powershell` and `bash`.

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
    * Contains: `create-xmpps1`
    * Summary: Runs through all Media- Files in a selected Folder (Option to choose to include Subfolders) and creates a XMP- Sidecar File

## `scripts/bash/`

This folder contains further subdirectories for Bash scripts:

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
    
## `scripts/userscripts/`

This folder contains further subdirectories for Userscript scripts (which can be used by Browser Extensions like Tampermonkey), categorized by function: 

### `gemini-snippets/`

Userscript for gemini.google.com to create a freely customizable Toolbar on the Website that allows to store your own Snippets for frequent use in Gemini
  
