# 🎧 Ambient Mixer Player (PySide6 / QML)

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg?logo=python&logoColor=white)](https://www.python.org/)
[![UI](https://img.shields.io/badge/UI-Qt%20Quick%20%2F%20QML%20(Material)-41CD52.svg?logo=qt&logoColor=white)](https://www.qt.io/)
[![Audio](https://img.shields.io/badge/Audio-Pygame%20Mixer-green.svg)](https://www.pygame.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Author](https://img.shields.io/badge/Author-Adromir-informational.svg)](https://github.com/adromir)

**Ambient Mixer Player** is a modern, cross-platform desktop audio player built with Python, PySide6 (QML Material Dark UI), and Pygame Mixer. It is specifically designed to load and play multi-track ambient soundscapes and presets downloaded via the [Ambient Mixer Downloader](../../powershell/music/ambient-mixer/).

---

## 🌟 Why Use This Tool?

While [ambient-mixer.com](https://ambient-mixer.com/) offers wonderful community soundscapes, playing them locally without an internet connection or without browser overhead requires dedicated multi-channel playback orchestration.

Each ambient mix consists of an XML configuration, a cover image, and up to 8 independent audio streams—some looping continuously (like rain, fire, or wind), while others trigger randomly at spaced intervals (like distant thunder, footsteps, or animal calls).

**Ambient Mixer Player** delivers an elegant, lightweight standalone player with granular per-channel acoustic controls and persistent preferences.

### Key Advantages

* 🎛️ **8-Channel Independent Audio Engine:** Supports up to 8 concurrent channels managed via `pygame.mixer` with zero audio stuttering.
* 🎚️ **Granular Sound Controls:**
  * **Volume:** Independent volume sliders (0% to 100%) for each channel.
  * **Stereo Balance (Pan):** Position individual sound elements freely across the stereo soundstage (Left - Center - Right).
  * **Mute Toggle:** Quickly silence individual channels without resetting their volume or timing.
  * **Dynamic Randomization:** Handles randomly scheduled ambient effects with customizable interval ranges (seconds, minutes, hours).
* 🎨 **Sleek Material Dark UI:** High-DPI responsive interface styled with Qt Quick Material Dark, featuring animated sliders, track labels, and visual feedback.
* 🖼️ **Cover Art & Metadata Integration:** Automatically renders the atmosphere's cover art, mix title, and author description directly from the preset folder and XML.
* ⏯️ **Master Controls:** Single-click "Play All" and "Stop All" channel toggles.
* 💾 **Persistent Settings:** Stores your default soundscape directory in `player_settings.conf` across app restarts.
* 🔗 **Perfect Companion:** Seamlessly loads preset folders produced by the repository's [Ambient Mixer Downloader](../../powershell/music/ambient-mixer/).

---

## 📸 Interface Preview

```text
+-----------------------------------------------------------------------------------------------+
| 🎧 Ambient Mixer Player                                                                       |
+-----------------------------------------------------------------------------------------------+
| [ 📂 Load Preset ]  [ ▶ Play All Channels ]                                   [ ⚙ Settings ]  |
+-----------------------------------------------------------------------------------------------+
| [ Cover Art ]   Title: The Shire - Rainy Evening                                              |
| +-----------+   Description: A gentle rain on the hobbit holes with a crackling fireplace...  |
| |  [Image]  |                                                                                 |
| +-----------+                                                                                 |
+-----------------------------------------------------------------------------------------------+
| [ Channels ]                                                                                  |
| +-------------------------------------------------------------------------------------------+ |
| | #1 Rain on Roof       | Vol: [====|===] 75% | Pan: [===|====] C | [🔊 Mute] | (🔁 Loop)    | |
| | #2 Hearth Fireplace   | Vol: [======|=] 85% | Pan: [=|======] L | [🔊 Mute] | (🔁 Loop)    | |
| | #3 Distant Thunder    | Vol: [==|=====] 40% | Pan: [======|=] R | [🔊 Mute] | (🎲 30s-120s)| |
| | #4 Owl / Birds        | Vol: [===|====] 50% | Pan: [====|===] C | [🔊 Mute] | (🎲 1m-5m)   | |
| +-------------------------------------------------------------------------------------------+ |
+-----------------------------------------------------------------------------------------------+
```

---

## 📋 Prerequisites & Installation

### 1. Python Environment

Requires **Python 3.8 or higher**.

### 2. Install Required Dependencies

Install the necessary Python packages via `pip`:

```bash
pip install PySide6 pygame untangle Pillow
```

| Package | Purpose |
| :--- | :--- |
| `PySide6` | Qt Quick / QML graphical user interface |
| `pygame` | Low-latency multi-channel audio playback |
| `untangle` | XML preset parsing |
| `Pillow` | Image validation and cover art handling |

---

## 🚀 Usage Guide

### 1. Launch the Player

Run the Python script:

```bash
cd E:\scripts\python\ambient-player
python ambient.player.py
```

### 2. Load and Play a Preset

1. Click **Load Preset** in the toolbar.
2. Select an XML file downloaded by the [Ambient Mixer Downloader](../../powershell/music/ambient-mixer/) (e.g., `the-shire.xml`).
3. The cover image, track names, and default balance/volume levels will populate automatically.
4. Click **Play All Channels** to start playback.
5. Fine-tune sliders to customize the mix to your preference.

---

## 📂 File Structure

- `ambient.player.py`: Application entry point, PySide6 backend controller, and Pygame audio mixing dispatcher.
- `player_ui.qml`: Declarative Qt Quick / QML interface layout with Material Dark styling.
- `player_settings.conf`: Local configuration file remembering the default preset directory.

---

## ⚠️ Disclaimer

Audio tracks and preset arrangements are subject to their respective creators' copyright on ambient-mixer.com. This software is an independent media player and is not affiliated with or endorsed by Ambient Mixer.

---

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Author:** Adromir  
**Website:** [https://github.com/adromir](https://github.com/adromir)
