# ⚡ Ventoy Local Boot Configurator

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![UI](https://img.shields.io/badge/UI-WPF%20XAML-purple.svg)](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/)
[![Ventoy](https://img.shields.io/badge/Ventoy-Compatible-brightgreen.svg)](https://www.ventoy.net/)
[![i18n](https://img.shields.io/badge/Languages-English%20%7C%20Deutsch-orange.svg)](#-multilingual-support)
[![Author](https://img.shields.io/badge/Author-Adromir-informational.svg)](https://github.com/adromir)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Ventoy Local Boot Configurator** is a modern, standalone WPF PowerShell GUI tool designed to configure and manage local disk boot options for [Ventoy](https://www.ventoy.net/) USB drives (`ventoy_grub.cfg`) and customize global Ventoy settings (`ventoy.json`).

With Ventoy, pressing **F6** in the main boot menu loads a custom Grub submenu (`ventoy_grub.cfg`). This utility makes creating and managing those boot entries effortless, safe, and deterministic—eliminating manual UUID lookups, brittle shell scripts, and broken configuration files.

---

## 🌟 Why Use This Tool?

While Ventoy is famous for booting ISO files seamlessly, booting local OS installations (such as Windows or Linux already installed on your NVMe/SATA drives) from a Ventoy USB stick requires custom GRUB2 entries with exact filesystem UUIDs and chainloader paths.

### Key Advantages

* 🎯 **Direct Boot-Sector UUID Detection:** Unlike generic tools that read Windows volume serials, this tool inspects the actual raw boot sectors (NTFS 64-bit, FAT32/16, exFAT, and ext2/3/4 superblocks) to generate the exact UUIDs GRUB requires.
* 💽 **Crystal-Clear Disk & Partition Identification:** Identifies disk models, bus types (NVMe, SATA, USB), partition numbers, filesystem labels, and sizes so you never mix up disks in multi-drive systems.
* 🧭 **Smart Boot-Role Recommendations:** Automatically distinguishes between **EFI System Partitions (ESP)**, **Windows OS Partitions (C:)**, **Linux Partitions**, and **Recovery Partitions**, offering dynamic guidance on which partition to select for UEFI vs. Legacy BIOS.
* ⚡ **Deterministic, Clean GRUB Entries:** Generates direct, targeted bootloader entries without cascading search loops (`if [ -f ... ] elif ...` scripts) for Windows UEFI, Ubuntu/Mint, Debian, Fedora, Arch, openSUSE, systemd-boot, Generic UEFI, Legacy BIOS (`bootmgr`), and PBR chainload (`+1`).
* ⭐ **1-Click Default Boot Option (`set default`):** Easily set and switch your default OS entry with a single click.
* ⏱️ **Auto-Boot, Default ISO & Menu Timeouts:** Set countdown timers for both the **Grub menu** (`set timeout=5`) and the **Ventoy main menu** (`VTOY_MENU_TIMEOUT`). *(Important: Ventoy's main menu countdown applies **only** to image files like `.iso`. Startup redirects such as `F6>`, `F4>`, or `VTOY_EXIT` trigger immediately upon boot without waiting for a timeout).*
* ⚡ **Universal Minimal GRUB2 ISO (Unattended Auto-Boot):** Seamlessly auto-boot into your local OS without pressing F6 by utilizing the included/downloadable `ventoy_localboot.iso`. Because Ventoy skips the menu countdown on `F6>`, booting `ventoy_localboot.iso` as `VTOY_DEFAULT_IMAGE` is the official way to have a countdown before automatically loading your local OS! The ISO contains a minimal, static GRUB2 instance that dynamically searches all storage devices for `/ventoy/ventoy_grub.cfg`—functioning independently of where the ISO resides on your USB drive (root, `/ventoy/`, or custom subfolder).
* 📥 **Minimal-ISO Downloader:** Directly download the latest multi-boot (UEFI x86_64, UEFI IA32, BIOS Legacy) `ventoy_localboot.iso` from GitHub Releases to any selected location on your USB drive.
* 💾 **Linux Live-Persistence Management & Built-in Creator:** Configure persistence mappings (`image` ↔ `backend`) in `ventoy.json`. Includes a built-in creator that downloads official Ventoy backend templates (`images.zip`) and extracts ready-to-use ext4/xfs persistence `.dat` files (256MB to 4GB) with distribution labels (`casper-rw`, `persistence`, `vtoycow`, `MX-Persist`) directly to your USB drive using Windows built-in `tar.exe`.
* 📋 **Full Entry Management & Reordering:** Edit titles, swap bootloader types, update UUIDs, and reorder boot entries (`⬆️ Move Up` / `⬇️ Move Down`).
* ⚙️ **Non-Destructive `ventoy.json` Editor:** Configure screen resolution (`gfxmode`), custom theme paths, default menu modes (list vs. tree), menu timeouts, and Windows 11 bypass options without wiping unmanaged configuration parameters.
* 🔒 **Safe Backups & Encoding:** Creates automatic timestamped backups before saving and writes UTF-8 without BOM to ensure 100% GRUB compatibility.
* 🌐 **Live Multilingual UI:** Clean separation of concerns with external XAML layout and instant language switching between English and German.

---

## 📸 Overview & Features

```
+-----------------------------------------------------------------------------------------------+
| ⚡ Ventoy-Laufwerk: [ G: - Ventoy (⚡ Ventoy erkannt)  v ] [ 🔄 Refresh Drives ]  Language: [ EN v ] |
+-----------------------------------------------------------------------------------------------+
| [ 💽 Local Partitions (Grub) ] [ 📋 Manage Entries ] [ ⚙️ Ventoy Settings ] [ 💾 Preview & Save ] |
|                                                                                               |
|  Select a local partition to boot (Press F6 in Ventoy to load this menu):                     |
|  +-----------------------------------------------------------------------------------------+  |
|  | Disk                     | Part | Letter | Label   | Size (GB) | FS    | Recommendation |  |
|  |--------------------------+------+--------+---------+-----------+-------+----------------|  |
|  | Disk 0: Samsung 980 Pro  | 1    | [Unm.] | ESP     | 0.50      | FAT32 | ⭐ EFI-Boot    |  |
|  | Disk 0: Samsung 980 Pro  | 3    | C:     | Windows | 1860.00   | NTFS  | ⊞ Windows OS   |  |
|  | Disk 1: Crucial MX500    | 1    | D:     | Linux   | 931.50    | ext4  | 🐧 Linux       |  |
|  +-----------------------------------------------------------------------------------------+  |
|                                                                                               |
|  💡 Selection Tip: For UEFI systems, select the ⭐ System (EFI) partition (FAT32)...          |
|                                                                                               |
|  Entry Name: [ Windows Boot Manager (Disk 0) ]  Bootloader: [ ⊞ Windows Boot Manager (UEFI) v ]  |
|  [x] ⭐ Set as default boot option (set default)           [ ➕ Add to Menu ]                 |
+-----------------------------------------------------------------------------------------------+
```

---

## 🚀 Supported Bootloaders & Targets

| Target OS / Bootloader | Type | Primary EFI Path & Fallback |
| :--- | :--- | :--- |
| **⊞ Windows Boot Manager** | UEFI | `/EFI/Microsoft/Boot/bootmgfw.efi` |
| **🐧 Ubuntu / Linux Mint** | UEFI | `/EFI/ubuntu/shimx64.efi` (Fallback: `grubx64.efi`) |
| **🐧 Debian** | UEFI | `/EFI/debian/shimx64.efi` (Fallback: `grubx64.efi`) |
| **🐧 Fedora / RHEL** | UEFI | `/EFI/fedora/shimx64.efi` (Fallback: `grubx64.efi`) |
| **🐧 Arch Linux / Manjaro** | UEFI | `/EFI/arch/grubx64.efi` (Fallback: `shimx64.efi`) |
| **🐧 openSUSE** | UEFI | `/EFI/opensuse/shim.efi` (Fallback: `grubx64.efi`) |
| **🐧 systemd-boot** | UEFI | `/EFI/systemd/systemd-bootx64.efi` |
| **⚡ Generic UEFI Bootloader** | UEFI | `/EFI/BOOT/BOOTX64.EFI` |
| **⊞ Windows Legacy BIOS** | BIOS / MBR | `ntldr /bootmgr` |
| **🔄 Partition Boot Record** | BIOS / MBR | `chainloader +1` |

---

## 📋 System Requirements

* **Operating System:** Windows 10 or Windows 11 (64-bit recommended)
* **PowerShell Version:**
  * Windows PowerShell 5.1, or
  * PowerShell 7.0+ (`pwsh`)
* **Privileges:** Administrator permissions (the script automatically requests UAC elevation and preserves your current PowerShell host).
* **Target Hardware:** USB drive formatted with [Ventoy](https://www.ventoy.net/).

---

## 🛠️ Installation & Quick Start

1. **Download or Clone the Repository:**
   ```powershell
   git clone https://github.com/adromir/powershell-scripts.git
   cd powershell-scripts/misc/ventoy_boot
   ```

2. **Run the Script:**
   * **In PowerShell 7:**
     ```powershell
     pwsh -ExecutionPolicy Bypass -File .\VentoyLocalBootEditor.ps1
     ```
   * **In Windows PowerShell 5.1:**
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\VentoyLocalBootEditor.ps1
     ```
   * *Or simply right-click `VentoyLocalBootEditor.ps1` and select **Run with PowerShell**.*

3. **Accept UAC Elevation:**
   When prompted, allow administrator access. The tool will elevate within the same PowerShell version you launched it from.

---

## 📖 Usage Guide

### 1. Select Ventoy USB Drive
* The application automatically scans all connected removable drives and pre-selects your Ventoy drive (identified by volume labels like `Ventoy` or `VTOYEFI` or the existence of a `/ventoy` folder).
* If you insert your USB stick after launching, click **🔄 Refresh Drives**.

### 2. Add Local Partition Boot Entries
1. In the **💽 Local Partitions (Grub)** tab, inspect the list of disks and partitions.
2. Select the target partition:
   * **For UEFI Systems (Recommended):** Select the **⭐ System (EFI)** partition (FAT32) of the drive containing your OS.
   * **For Legacy BIOS Systems:** Select the active OS partition (e.g. `C:`).
3. The tool automatically fills in:
   * A clean, descriptive **Entry Name**.
   * The appropriate **Expected Bootloader** type.
4. *(Optional)* Check **⭐ Set as default boot option** to make this entry the default choice.
5. Click **➕ Add to Menu**.

### 3. Manage & Reorder Boot Entries
In the **📋 Manage Entries** tab:
* **Change Default Entry:** Select any entry in the list and click **⭐ Set as Default**.
* **Reorder Entries:** Use **⬆️ Move Up** and **⬇️ Move Down** to organize the boot order.
* **Edit Entry:** Modify the display name, change the bootloader type, or update the UUID in the right-hand panel, then click **💾 Save Changes to Entry**.
* **Delete Entry:** Remove unwanted boot entries with **🗑️ Delete Entry**.

### 4. Configure Ventoy Global Options (`ventoy.json`)
In the **⚙️ Ventoy Settings (JSON)** tab:
* Set custom screen resolution (e.g., `1920x1080` or `max`).
* Specify custom GRUB theme file paths (e.g., `/ventoy/theme/theme.txt`).
* Toggle between **List Mode** (`0`) and **Tree Mode** (`1`).
* Enable **Windows 11 Bypass** to bypass TPM 2.0, CPU, and Secure Boot requirements during Windows 11 setup.
* **Download Minimal ISO:** Click `⚡ Minimal-ISO laden...` to download `ventoy_localboot.iso` to any folder on your USB drive.
* Click **💾 Save ventoy.json** (existing unmanaged properties in `ventoy.json` are preserved).

### 5. Preview & Save to USB
In the **💾 Preview & Save (Grub)** tab:
* Review the generated `ventoy_grub.cfg` syntax.
* Make manual adjustments directly in the editor if desired.
* Click **💾 Save to ventoy_grub.cfg**. A timestamped backup (`ventoy_grub.cfg.backup_YYYYMMDD_HHMMSS`) is created automatically.

### 6. Booting with Ventoy
1. **Interactive Mode:** Reboot your computer and boot from your Ventoy USB drive. In the Ventoy main menu, press **F6** (or select *Local Boot*).
2. **Automated Timeout Mode:** If you configured `VTOY_DEFAULT_IMAGE` with `ventoy_localboot.iso` and a timeout (e.g. 5s), Ventoy automatically boots the minimal ISO when the countdown expires. The ISO immediately finds and loads `/ventoy/ventoy_grub.cfg`, booting your configured default operating system!

---

## ⚡ Universal Minimal GRUB2 ISO (`ventoy_localboot.iso`)

### How It Works
Ventoy natively supports setting a default image (`VTOY_DEFAULT_IMAGE`) that boots automatically when `VTOY_MENU_TIMEOUT` expires. `ventoy_localboot.iso` is a tiny, static multi-boot image designed specifically for this role:

```
[ Ventoy Boot Menu (Countdown: 5s) ]
               │
               ▼ (Auto-boots VTOY_DEFAULT_IMAGE)
[ ventoy_localboot.iso ]
               │
               ▼ (Embedded GRUB2 search)
`search --no-floppy --file --set=root /ventoy/ventoy_grub.cfg`
               │
               ▼ (Executes configuration)
`configfile /ventoy/ventoy_grub.cfg`
               │
               ▼
[ Local Boot Menu / Default OS boots automatically! ]
```

### Key Technical Characteristics
* **Multi-Platform Support:** Fully supports **UEFI x86_64**, **UEFI IA32**, and **BIOS / Legacy MBR**.
* **Embedded Drivers:** Pre-compiled with `part_gpt`, `part_msdos`, `fat`, `exfat`, `ntfs`, `ext2` (ext2/3/4), `iso9660`, `search`, and `configfile`.
* **Path & Folder Independent:** The embedded GRUB scans all connected storage drives and partitions for `/ventoy/ventoy_grub.cfg`. Regardless of whether `ventoy_localboot.iso` is placed in the root directory (`/ventoy_localboot.iso`), `/ventoy/`, or a custom subfolder (`/isos/`), it will always discover and execute the config file on your Ventoy data partition.
* **Fallback & Error Handling:** If `/ventoy/ventoy_grub.cfg` cannot be found on any disk, the ISO displays a clear diagnostic message and halts safely with a prompt (`read`).

### ⏱️ Critical Nuance: Main Menu Timeout vs. Startup Redirects (`F6>`)

> [!IMPORTANT]
> **Ventoy's built-in `VTOY_MENU_TIMEOUT` does NOT apply to startup redirects (such as `"F6>"`, `"F4>"`, `"F5>"`, `"F2>"`, or `"VTOY_EXIT"`).**
>
> In Ventoy:
> * Setting `VTOY_DEFAULT_IMAGE` to a hotkey action like `"F6>"` makes Ventoy jump **immediately on startup** to the local boot menu, bypassing the main menu countdown completely.
> * Setting `VTOY_DEFAULT_IMAGE` to an actual image file (such as `"/ventoy/ventoy_localboot.iso"` or `"/ISO/ubuntu.iso"`) causes Ventoy to display the main menu, run the `VTOY_MENU_TIMEOUT` countdown, and auto-boot that image when the timer expires.

#### Boot Flow Comparison:

| Desired Boot Behavior | Ventoy Config (`ventoy.json`) | Grub Config (`ventoy_grub.cfg`) | What Actually Happens |
| :--- | :--- | :--- | :--- |
| **Main Menu Countdown ➔ Local OS Auto-Boot** | `VTOY_DEFAULT_IMAGE: "/ventoy_localboot.iso"`<br>`VTOY_MENU_TIMEOUT: 5` | `set timeout=0`<br>`set default="Windows"` | Ventoy displays the main menu, counts down 5s. When expired, boots `ventoy_localboot.iso`, which immediately launches `ventoy_grub.cfg` and starts Windows without user interaction. |
| **Immediate Jump to Local Grub Menu (Countdown in Grub)** | `VTOY_DEFAULT_IMAGE: "F6>"`<br>*(Menu timeout ignored)* | `set timeout=5`<br>`set default="Windows"` | Ventoy skips its main menu immediately at boot and directly opens `ventoy_grub.cfg`, where GRUB counts down 5s before booting Windows. |
| **Main Menu Countdown ➔ Specific ISO** | `VTOY_DEFAULT_IMAGE: "/ISOs/ubuntu.iso"`<br>`VTOY_MENU_TIMEOUT: 10` | N/A | Ventoy waits 10s in the main menu, then boots `ubuntu.iso`. |
| **Manual Selection Only** | `VTOY_DEFAULT_IMAGE` omitted / `""` | `set timeout=-1` | Ventoy waits indefinitely in the main menu for user input. |

### Example `ventoy.json` Configuration
```json
{
  "control": [
    { "VTOY_DEFAULT_MENU_MODE": "0" },
    { "VTOY_MENU_TIMEOUT": "5" },
    { "VTOY_DEFAULT_IMAGE": "/ventoy/ventoy_localboot.iso" }
  ]
}
```

### GitHub Actions Build Automation
The ISO is built directly inside GitHub Actions using the `.github/workflows/build-ventoy-iso.yml` workflow:
* **Trigger:** Manual dispatch (`workflow_dispatch`).
* **Environment:** `ubuntu-latest` with `grub-pc-bin`, `grub-efi-amd64-bin`, `grub-efi-ia32-bin`, `xorriso`, and `mtools`.
* **Release:** Automatically generates SHA256 checksums and attaches `ventoy_localboot.iso` to the GitHub Release.

## 📂 Project Structure

```
misc/ventoy_boot/
├── MainWindow.xaml               # WPF XAML user interface layout
├── VentoyLocalBootEditor.ps1     # Core controller, logic, elevation & i18n
├── lang/
│   ├── de.json                   # German language strings (90 keys)
│   └── en.json                   # English language strings (90 keys)
├── README.md                     # Documentation
└── MEMORY.md                     # Architectural memory & decision log
```

---

## 🌐 Multilingual Support

The tool supports live runtime language switching:
* **English (🇬🇧)**
* **Deutsch (🇩🇪)**

The user interface automatically defaults to your Windows system language and can be switched at any time via the top-right language dropdown without restarting the application.

---

## 📝 Generated GRUB Configuration Example

Here is an example of the clean, deterministic `ventoy_grub.cfg` output produced by the tool:

```grub
set default="Windows Boot Manager (Disk 0: Samsung 980 Pro - Part 1)"

menuentry "Windows Boot Manager (Disk 0: Samsung 980 Pro - Part 1)" --class=windows --class=os {
	insmod part_gpt
	insmod fat
	search --no-floppy --set=root --fs-uuid 328C-99D9
	chainloader /EFI/Microsoft/Boot/bootmgfw.efi
	boot
}

menuentry "Ubuntu Linux (Disk 1: Crucial MX500 - Part 1)" --class=ubuntu --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	search --no-floppy --set=root --fs-uuid 94A2-B3C4
	chainloader /EFI/ubuntu/grubx64.efi
	boot
}
```

---

## ⚠️ Disclaimer

This tool writes configuration files directly to your Ventoy USB drive. While automatic backups are created prior to saving:
* Always ensure you have backups of important data.
* Modifying boot settings on production systems should be done with care.
* This project is not officially affiliated with the Ventoy development team.

---

## 👤 Author

**Adromir**  
* GitHub: [@adromir](https://github.com/adromir)  
* Website: [https://github.com/adromir](https://github.com/adromir)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](../../LICENSE) file for details.
