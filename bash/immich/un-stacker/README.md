# Immich Stacking & Unstacking Bash Scripts 🗂️✨

This document provides an overview and usage instructions for two Bash scripts designed to manage asset stacks in an [Immich](https://immich.app/) instance:
1.  **Immich Auto-Stacker**: Specifically designed to stack JPG/JPEG files with their corresponding RAW (DNG, CR2, etc.) counterparts.
2.  **Immich Unstacker**: Designed to find and dissolve all existing stacks in your Immich library.

---

## ⚠️ Important Notes & Disclaimer

* **BACKUP YOUR IMMICH DATA**: Before running these scripts (especially the Unstacker or the Stacker with `DRY_RUN_CONFIG="false"`), **ensure you have a complete and verified backup of your Immich database and library files.** Incorrect usage or unexpected API behavior could lead to unintended changes or data loss.
* **USE AT YOUR OWN RISK**: These scripts are provided "as-is" without any warranties. The authors or contributors are not responsible for any damage or data loss that may occur from their use. You are solely responsible for understanding the script's functionality and for any consequences of running it on your system and Immich instance.
* **API Interaction**: These scripts interact directly with your Immich API. Ensure your API key has the necessary permissions.
* **Testing**: Always test with `DRY_RUN_CONFIG="true"` first to see what actions the scripts *would* perform before making any actual changes.
* **Performance**: For very large libraries, the scripts (especially the initial asset fetching and scanning parts) can take a significant amount of time. Use the `MAX_ASSETS_TO_PROCESS_CONFIG` or `MAX_ASSETS_TO_SCAN_CONFIG` for initial testing.

---

## 🛠️ Common Prerequisites

Both scripts require the following command-line tools to be installed and accessible in your system's PATH:

* **`jq`**: A lightweight and flexible command-line JSON processor.
    * Installation: `sudo apt install jq` (Debian/Ubuntu) or check your OS package manager.
* **`curl`**: A command-line tool for transferring data with URLs.
    * Installation: `sudo apt install curl` (Debian/Ubuntu) or check your OS package manager.
* **`mktemp`**: Utility to create temporary files (usually part of `coreutils`).

---

## ⚙️ Common Configuration Variables (within each script)

The following configuration variables are common to both scripts and need to be set directly within each script file:

| Variable                      | Default Value | Description                                                                                                                               |
| :---------------------------- | :------------ | :---------------------------------------------------------------------------------------------------------------------------------------- |
| `API_KEY_CONFIG`              | `""`          | **Required**. Your Immich API Key. This key needs permissions to read asset metadata and to create/modify/delete stacks as applicable.         |
| `API_URL_CONFIG`              | `""`          | **Required**. The base URL of your Immich instance (e.g., `http://immich.example.com` or `http://your-server-ip:port`). The script will append `/api` automatically. |
| `DRY_RUN_CONFIG`              | (varies)      | If `"true"`, no changes are made to Immich; actions are only logged. **Set to `"false"` for live run. Highly recommended for initial tests.** |
| `CURL_CONNECT_TIMEOUT_CONFIG` | `"15"`        | The maximum time in seconds that `curl` will spend trying to connect to the Immich server for each API request.                               |
| `CURL_MAX_TIME_CONFIG`        | `"90"`        | The maximum total time in seconds that a single `curl` API request is allowed to take.                                                        |
| `DEBUG_CURL_COMMAND_CONFIG`   | `"false"`     | If `"true"`, logs the full `curl` commands being executed (API key is in headers, not directly in the logged command string for security).    |

---

## 1. Immich Auto-Stacker (RAW+JPEG) 켜기

This script automates the process of creating stacks in Immich, specifically designed to pair a primary JPG/JPEG image with its corresponding RAW image versions (e.g., `.dng`, `.cr2`).

### 🎯 Purpose

To organize related images by stacking RAW files under a primary JPG, making your library cleaner while preserving access to the RAW originals. JPGs will always be the parent.

### ✨ Key Features

* **RAW+JPEG Pairing**: Identifies JPG/JPEG files and their corresponding RAW files based on the same base filename (e.g., `photo1.jpg` and `photo1.dng`).
* **JPG as Parent**: Ensures that the JPG/JPEG file is always selected as the parent/cover of the stack.
* **Skips Existing Stacks**: By default, it will not modify assets that are already part of a stack (either as a parent or a child). This behavior is controlled by `SKIP_PREVIOUS_CONFIG`.
* **Type Filtering**: Can be configured to only process `IMAGE` types via `ASSET_TYPE_FILTER_CONFIG`.
* **Asset Limit**: Allows limiting the number of assets fetched and processed for testing purposes via `MAX_ASSETS_TO_PROCESS_CONFIG`.

### ⚙️ Stacker-Specific Configuration Variables (within the script)

Refer to the "Common Configuration Variables" section above for `API_KEY_CONFIG`, `API_URL_CONFIG`, `DRY_RUN_CONFIG`, `CURL_CONNECT_TIMEOUT_CONFIG`, `CURL_MAX_TIME_CONFIG`, and `DEBUG_CURL_COMMAND_CONFIG`.

| Variable                         | Default Value | Description                                                                                                                                                                                             |
| :------------------------------- | :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SKIP_PREVIOUS_CONFIG`           | `"true"`      | If set to `"true"`, the script will skip processing any asset that is already part of a stack. Set to `"false"` to re-evaluate all assets (use with caution).                                                |
| `CRITERIA_DEF_CONFIG`            | `()`          | **Not used by default for RAW+JPEG stacking.** Intended for advanced/custom stacking criteria if you modify the script's core logic. The default RAW+JPEG logic uses hardcoded filename-based pairing. |
| `PARENT_PROMOTE_CONFIG`          | `""`          | Comma-separated keywords (e.g., `"COVER,PRIMARY"`). If a JPG's filename contains these, it gets a higher priority as a parent.                                                                             |
| `ASSET_TYPE_FILTER_CONFIG`       | `"IMAGE"`     | Filters assets by type. Default is `"IMAGE"`. Set to empty to process all types (though RAW+JPEG logic is image-focused).                                                                                  |
| `MAX_ASSETS_TO_PROCESS_CONFIG`   | `"0"`         | Limits the number of assets fetched. `0` processes all. Useful for testing.                                                                                                                             |
| `DEBUG_SHOW_JSON_CONFIG`       | `"false"`     | If `"true"`, logs the full JSON data of individual assets being processed in `process_single_stack`.                                                                                                      |
| `RAW_EXTENSIONS` (Array)         | `(...)`       | Internal list of RAW file extensions (e.g., "dng", "cr2") to identify as children.                                                                                                                         |


### ▶️ Usage

1.  **Edit the script**: Open the `bash_immich_stacker` script in a text editor.
2.  **Configure**: Fill in the common variables (`API_KEY_CONFIG`, `API_URL_CONFIG`) and review stacker-specific ones.
    * **Recommendation**: For the first run, set `DRY_RUN_CONFIG="true"` and `MAX_ASSETS_TO_PROCESS_CONFIG` to a small number (e.g., `100`) to test.
3.  **Make executable**: `chmod +x bash_immich_stacker`
4.  **Run**: `./bash_immich_stacker`

The script will log its actions to `stderr`.

### 📝 Important Notes for Stacker

* The script specifically looks for a JPG/JPEG file and then searches for RAW files with the **exact same base filename** (e.g., `photo1` from `photo1.jpg` and `photo1.dng`).
* If multiple RAW files match a single JPG, they will all be added as children to the JPG parent.
* The `get_parent_sort_key_for_asset_json` function heavily prioritizes JPG/JPEG files as stack covers.

---

## 2. Immich Unstacker 💨

This script is designed to dissolve all existing asset stacks in your Immich instance, making every asset an individual item again.

### 🎯 Purpose

To revert any stacking that has been done, either by the Auto-Stacker script or manually within Immich.

### ✨ Key Features

* **Comprehensive Unstacking**: Aims to find all stacks and unstack them.
* **Stack ID Discovery**:
    1.  Fetches a list of assets (optionally filtered by type, defaulting to IMAGE).
    2.  For each JPG/JPEG asset, it queries the `/api/stacks?primaryAssetId={assetId}` endpoint.
    3.  If a stack is found where the JPG is the primary asset, its Stack ID (the ID of the stack entity itself) is collected.
* **Bulk Deletion**: Sends a single `DELETE /api/stacks` request with all collected unique Stack IDs.
* **Asset Limit for Scan**: Allows limiting the number of assets scanned to find stack covers for testing.

### ⚙️ Unstacker-Specific Configuration Variables (within the script)

Refer to the "Common Configuration Variables" section above for `API_KEY_CONFIG`, `API_URL_CONFIG`, `DRY_RUN_CONFIG`, `CURL_CONNECT_TIMEOUT_CONFIG`, `CURL_MAX_TIME_CONFIG`, and `DEBUG_CURL_COMMAND_CONFIG`.

| Variable                             | Default Value | Description                                                                                                                               |
| :----------------------------------- | :------------ | :---------------------------------------------------------------------------------------------------------------------------------------- |
| `MAX_ASSETS_TO_SCAN_CONFIG`          | `"50"`        | Limits the number of assets scanned to find stack covers. `0` means scan all. Useful for testing.                                           |
| `ASSET_TYPE_FILTER_UNSTACKER_CONFIG` | `"IMAGE"`     | Filters the initial list of assets to scan for stack covers. Set to `"IMAGE"`, `"VIDEO"`, or empty to scan all types.                         |

### ▶️ Usage

1.  **Edit the script**: Open the `bash_immich_unstacker` script in a text editor.
2.  **Configure**: Fill in the common variables (`API_KEY_CONFIG`, `API_URL_CONFIG`) and review unstacker-specific ones.
    * **CRITICAL**: For the first run, ensure `DRY_RUN_CONFIG="true"` to prevent accidental unstacking.
    * Set `MAX_ASSETS_TO_SCAN_CONFIG` to a small number for initial testing if desired.
3.  **Make executable**: `chmod +x bash_immich_unstacker`
4.  **Run**: `./bash_immich_unstacker`

The script will log its actions to `stderr`.

### 📝 Important Notes for Unstacker

* The script relies on the `GET /api/stacks?primaryAssetId={assetId}` endpoint returning the actual Stack Entity ID if the queried asset is a stack cover.
* It only checks JPG/JPEG files as potential stack covers by default (due to `ASSET_TYPE_FILTER_UNSTACKER_CONFIG`).

---

## 📜 License

MIT License

Copyright (c) 2024 [Your Name or Alias - Or leave this generic if preferred]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

Good luck, and use these scripts responsibly! 🚀
