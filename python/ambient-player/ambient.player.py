# coding: utf-8
"""
ambient_player_qt.py - Plays a downloaded Ambient Mixer preset XML file using PySide6, QML, and Pygame.

Description:
Loads a preset XML file created by the Ambient Mixer Downloader script.
Provides a QML interface with Mute, Volume, Balance, and Random controls
for each audio channel, arranged horizontally below title/description.
Includes a Play/Stop All button.
Displays the cover image and title/description associated with the preset.
Plays the local audio files specified in the XML, either looping or randomly triggered.
Includes a settings mechanism to set the default preset folder.
Playback does NOT start automatically on load.

Requirements: PySide6, pygame, untangle, Pillow
Install using: pip install PySide6 pygame untangle Pillow
"""
__author__ = "Adromir / Gemini (Based on original CLI script by Philooz)"
__copyright__ = "2024"

import os
import sys
import configparser
import random
import time
from pathlib import Path

# --- Dependency Check (Basic) ---
try:
    import pygame
    print(f"Pygame version: {pygame.version.ver}")
except ImportError:
    print("ERROR: Pygame not found. Please install it using: pip install pygame", file=sys.stderr)
    sys.exit(1)

try:
    import untangle
    print("Untangle library found.")
except ImportError:
    print("ERROR: Untangle not found. Please install it using: pip install untangle", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
    print("Pillow library found (optional, for image path validation).")
except ImportError:
    print("Warning: Pillow not found (pip install Pillow). Cover image display might rely solely on QML.")
    Image = None

# --- PySide6 Imports ---
try:
    from PySide6.QtCore import (QObject, QUrl, Slot, Property as pyqtProperty,
                                Signal as pyqtSignal, QTimer, Qt)
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtWidgets import QFileDialog, QApplication

except ImportError as e:
     print(f"ERROR: PySide6 not found or missing components ({e}).\nPlease install it using: pip install PySide6", file=sys.stderr)
     sys.exit(1)


# --- Pygame Initialization ---
try:
    pygame.mixer.pre_init(44100, -16, 2, 2048)
    pygame.init()
    pygame.mixer.set_num_channels(8)
    print(f"Pygame Mixer initialized with {pygame.mixer.get_num_channels()} channels.")
except pygame.error as e:
     print(f"ERROR: Failed to initialize Pygame mixer: {e}", file=sys.stderr)

# --- Global Variables & Settings ---
script_dir = Path(__file__).parent.resolve()
settings_file = script_dir / "player_settings.conf"
default_preset_folder = str(script_dir)

RANDOM_UNIT_SECONDS = { 's': 1, 'm': 60, 'h': 3600 }
TIMER_INTERVAL_MS = 500

def load_settings():
    global default_preset_folder
    config = configparser.ConfigParser()
    if settings_file.exists():
        try:
            config.read(settings_file)
            loaded_path = config.get('Settings', 'DefaultPresetFolder', fallback=str(script_dir))
            if Path(loaded_path).is_dir():
                default_preset_folder = loaded_path
                print(f"Loaded default preset folder: {default_preset_folder}")
            else:
                print(f"Warning: Saved default folder not found ('{loaded_path}'). Using script directory.")
                default_preset_folder = str(script_dir)
        except Exception as e:
            print(f"Error loading settings file '{settings_file}': {e}")
            default_preset_folder = str(script_dir)
    else:
        print("Settings file not found. Using script directory as default.")
        default_preset_folder = str(script_dir)

def save_settings():
    config = configparser.ConfigParser()
    config['Settings'] = {'DefaultPresetFolder': default_preset_folder}
    try:
        with open(settings_file, 'w') as configfile:
            config.write(configfile)
        print(f"Settings saved to {settings_file}")
    except Exception as e:
        print(f"Error saving settings: {e}")


# --- Backend Class ---
class PlayerBackend(QObject):
    # Signals
    statusTextChanged = pyqtSignal(str, arguments=['status'])
    presetPathChanged = pyqtSignal(str, arguments=['path'])
    coverImagePathChanged = pyqtSignal(str, arguments=['path'])
    titleChanged = pyqtSignal(str, arguments=['title'])
    descriptionChanged = pyqtSignal(str, arguments=['description'])
    channelsChanged = pyqtSignal()
    channelPropsChanged = pyqtSignal(int, str, 'QVariant', arguments=['channelId', 'propName', 'propValue'])
    isPlayingAllChanged = pyqtSignal(bool, arguments=['isPlayingAll'])


    def __init__(self, parent=None):
        super().__init__(parent)
        self._presetPathLabel = "No file loaded."
        self._statusText = "Ready. Load a preset XML file."
        self._coverImagePath = ""
        self._title = "No Preset Loaded"
        self._description = ""
        self._channels = []
        self._active_pygame_channels = {}
        self._xml_preset_dir = None
        self._is_playing_all = False # Internal flag tracking if *any* channel is playing

        self._random_timer = QTimer(self)
        self._random_timer.timeout.connect(self._check_random_playback)
        self._random_timer.setInterval(TIMER_INTERVAL_MS)

        load_settings()

    # --- Properties ---
    @pyqtProperty(str, notify=presetPathChanged)
    def presetPathLabel(self): return self._presetPathLabel

    @pyqtProperty(str, notify=statusTextChanged)
    def statusText(self): return self._statusText

    @pyqtProperty(str, notify=coverImagePathChanged)
    def coverImagePath(self):
        if self._coverImagePath and Path(self._coverImagePath).exists():
            abs_path = str(Path(self._coverImagePath).resolve())
            return QUrl.fromLocalFile(abs_path).toString()
        return ""

    @pyqtProperty(str, notify=titleChanged)
    def title(self): return self._title

    @pyqtProperty(str, notify=descriptionChanged)
    def description(self): return self._description

    @pyqtProperty('QVariantList', notify=channelsChanged)
    def channelModel(self): return self._channels

    @pyqtProperty(bool, notify=isPlayingAllChanged)
    def isPlayingAll(self): return self._is_playing_all

    # --- Slots ---
    @Slot()
    def loadPreset(self):
        global default_preset_folder
        initial_dir = default_preset_folder if Path(default_preset_folder).is_dir() else str(script_dir)

        qapp_instance = QApplication.instance()
        if not qapp_instance:
            app_argv = sys.argv if hasattr(sys, 'argv') else []
            qapp_instance = QApplication(app_argv)

        filepath, _ = QFileDialog.getOpenFileName(
            None, "Select Ambient Mixer Preset XML File", initial_dir,
            "XML Files (*.xml);;All Files (*.*)"
        )
        if not filepath: return

        self._updateStatus("Loading preset...")
        self._stopAllSounds()
        self._channels = []
        self._active_pygame_channels = {}
        self._title = "Loading..."
        self._description = ""
        self._coverImagePath = ""
        self.channelsChanged.emit()
        self.titleChanged.emit(self._title)
        self.descriptionChanged.emit(self._description)
        self.coverImagePathChanged.emit(self._coverImagePath)
        self._check_playing_all_state()

        xml_path = Path(filepath)
        self._xml_preset_dir = xml_path.parent
        self._presetPathLabel = xml_path.name
        self.presetPathChanged.emit(self._presetPathLabel)

        self._find_and_set_cover_image()

        try:
            xml_obj = untangle.parse(str(xml_path))
            try: self._title = getattr(xml_obj.audio_template.title, 'cdata', xml_path.stem).strip()
            except AttributeError: self._title = xml_path.stem
            try: self._description = getattr(xml_obj.audio_template.description, 'cdata', "").strip()
            except AttributeError: self._description = ""
            self.titleChanged.emit(self._title)
            self.descriptionChanged.emit(self._description)

            channels_found = 0
            temp_channels = []

            for i in range(8):
                channel_id = i
                try:
                    channel_node = getattr(xml_obj.audio_template, f"channel{i+1}")
                    name = getattr(channel_node.name_audio, 'cdata', f"Channel {i+1}").strip()
                    relative_path = getattr(channel_node.url_audio, 'cdata', "").strip()
                    volume_str = getattr(channel_node.volume, 'cdata', "75").strip()
                    balance_str = getattr(channel_node.balance, 'cdata', "0").strip()
                    is_random_str = getattr(channel_node.random, 'cdata', "false").strip().lower()
                    is_random = (is_random_str == "true")
                    is_muted_str = getattr(channel_node.mute, 'cdata', "false").strip().lower()
                    is_muted = (is_muted_str == "true")
                    random_counter_str = getattr(channel_node.random_counter, 'cdata', "1").strip()
                    random_unit = getattr(channel_node.random_unit, 'cdata', "h").strip().lower()

                    if not relative_path: continue

                    volume = float(volume_str) if volume_str else 75.0
                    balance = float(balance_str) if balance_str else 0.0
                    try: random_counter = int(random_counter_str)
                    except ValueError: random_counter = 1
                    if random_unit == '1m': random_unit = 'm'
                    elif random_unit == '10m': random_unit = 'm'; random_counter *= 10
                    elif random_unit == '1h': random_unit = 'h'
                    elif random_unit not in ['s', 'm', 'h']: random_unit = 'h'

                    channel_data_for_qml = {
                        "channelId": channel_id, "name": name, "relativePath": relative_path,
                        "volume": volume, "balance": balance, "isMuted": is_muted,
                        "isRandom": is_random, "randomCounter": random_counter, "randomUnit": random_unit,
                        "isLoaded": False
                    }

                    sound_obj = self._load_sound_for_channel(channel_id, relative_path)
                    if sound_obj:
                        channel_data_for_qml["isLoaded"] = True
                        pygame_channel = pygame.mixer.Channel(channel_id)
                        self._active_pygame_channels[channel_id] = {
                            'sound': sound_obj,
                            'pygame_channel': pygame_channel,
                            'next_random_play_time': 0
                        }
                        self._apply_mute_state(channel_id, is_muted, initial_volume=volume, initial_balance=balance)
                        if is_random and not is_muted:
                             self._schedule_next_random_play(channel_id)

                    temp_channels.append(channel_data_for_qml)
                    channels_found += 1

                except AttributeError: pass
                except Exception as e: print(f"Error processing Channel {i+1} from XML: {e}")

            self._channels = temp_channels
            self.channelsChanged.emit()

            if channels_found > 0:
                self._updateStatus(f"Preset '{self._title}' loaded ({channels_found} channels). Ready to play.")
                self._random_timer.start()
            else:
                self._updateStatus("Preset loaded, but no valid channels found.")
            self._check_playing_all_state()

        except FileNotFoundError:
             self._updateStatus("Error: XML file not found.")
             self._channels = []; self.channelsChanged.emit()
             self._title = "Error"; self.titleChanged.emit(self._title)
             self._description = "XML file not found."; self.descriptionChanged.emit(self._description)
             self._check_playing_all_state()
        except Exception as e:
            self._updateStatus(f"Error parsing XML: {e}")
            print(f"XML Parsing Error: {e}")
            self._channels = []; self.channelsChanged.emit()
            self._title = "Error"; self.titleChanged.emit(self._title)
            self._description = f"Could not parse XML file.\n{e}"; self.descriptionChanged.emit(self._description)
            self._check_playing_all_state()

    @Slot(int)
    def toggleMute(self, channel_id):
        if channel_id not in self._active_pygame_channels: return
        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml: return

        new_mute_state = not channel_data_qml['isMuted']
        channel_data_qml['isMuted'] = new_mute_state
        self._apply_mute_state(channel_id, new_mute_state) # Handles setting volume to 0 or restoring

        pygame_channel = self._active_pygame_channels[channel_id]['pygame_channel']

        # *** UPDATED LOGIC: Only stop sound if muting ***
        if new_mute_state:
            print(f"Muting and stopping channel {channel_id}")
            pygame_channel.stop()
            if channel_data_qml['isRandom']:
                self._active_pygame_channels[channel_id]['next_random_play_time'] = 0 # Clear schedule
        # If unmuting a random channel, just schedule it (don't start)
        elif channel_data_qml['isRandom']:
             print(f"Unmuting random channel {channel_id}, scheduling next play.")
             self._schedule_next_random_play(channel_id)
        # If unmuting a looping channel, start it ONLY IF global playback is active
        elif not channel_data_qml['isRandom']:
             if self._is_playing_all: # Check global state
                 if not pygame_channel.get_busy():
                     print(f"Unmuting looping channel {channel_id} during active playback, starting loop.")
                     sound_obj = self._active_pygame_channels[channel_id]['sound']
                     pygame_channel.play(sound_obj, loops=-1)
                 else:
                      print(f"Unmuting looping channel {channel_id}, already playing.")
             else:
                  print(f"Unmuting looping channel {channel_id}, global playback stopped.")


        self.channelPropsChanged.emit(channel_id, 'isMuted', new_mute_state)
        # Check playing state *after* potential start/stop
        self._check_playing_all_state()

    @Slot(int, float)
    def setVolume(self, channel_id, volume):
        if channel_id in self._active_pygame_channels:
            for ch_dict in self._channels:
                if ch_dict['channelId'] == channel_id:
                    ch_dict['volume'] = volume
                    # *** Apply volume change respecting mute state ***
                    self._apply_mute_state(channel_id, ch_dict['isMuted'], initial_volume=volume, initial_balance=ch_dict['balance'])
                    break

    @Slot(int, float)
    def setBalance(self, channel_id, balance):
         if channel_id in self._active_pygame_channels:
            for ch_dict in self._channels:
                if ch_dict['channelId'] == channel_id:
                    ch_dict['balance'] = balance
                    # *** Apply balance change respecting mute state ***
                    self._apply_mute_state(channel_id, ch_dict['isMuted'], initial_volume=ch_dict['volume'], initial_balance=balance)
                    break

    @Slot(int, bool)
    def setRandomEnabled(self, channel_id, is_enabled):
        if channel_id not in self._active_pygame_channels: return
        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml: return

        channel_data_qml['isRandom'] = is_enabled
        print(f"Channel {channel_id} random set to {is_enabled}")

        pygame_channel = self._active_pygame_channels[channel_id]['pygame_channel']
        sound_obj = self._active_pygame_channels[channel_id]['sound']

        was_playing = pygame_channel.get_busy()
        pygame_channel.stop() # Stop current playback

        # Only restart if global playback is active AND channel is not muted
        if self._is_playing_all and not channel_data_qml['isMuted']:
            if is_enabled:
                self._schedule_next_random_play(channel_id)
            else: # Looping enabled
                 pygame_channel.play(sound_obj, loops=-1)

        self.channelPropsChanged.emit(channel_id, 'isRandom', is_enabled)
        # Check state again as stopping/starting might have changed it
        self._check_playing_all_state()


    @Slot(int, int)
    def setRandomCounter(self, channel_id, count):
        if channel_id not in self._active_pygame_channels: return
        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml: return
        count = max(1, int(count))
        channel_data_qml['randomCounter'] = count
        print(f"Channel {channel_id} random count set to {count}")
        if channel_data_qml['isRandom'] and not channel_data_qml['isMuted']:
            self._schedule_next_random_play(channel_id)
        self.channelPropsChanged.emit(channel_id, 'randomCounter', count)


    @Slot(int, str)
    def setRandomUnit(self, channel_id, unit_char):
        if channel_id not in self._active_pygame_channels: return
        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml: return
        unit_char = unit_char.lower()
        if unit_char not in RANDOM_UNIT_SECONDS:
            print(f"Warning: Invalid random unit '{unit_char}' received for channel {channel_id}. Ignoring.")
            self.channelPropsChanged.emit(channel_id, 'randomUnit', channel_data_qml['randomUnit'])
            return

        channel_data_qml['randomUnit'] = unit_char
        print(f"Channel {channel_id} random unit set to {unit_char}")
        if channel_data_qml['isRandom'] and not channel_data_qml['isMuted']:
            self._schedule_next_random_play(channel_id)
        self.channelPropsChanged.emit(channel_id, 'randomUnit', unit_char)


    @Slot()
    def playAll(self):
        print("Starting all non-muted channels...")
        count_started = 0
        for channel_id, pygame_info in self._active_pygame_channels.items():
             channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
             if channel_data_qml and not channel_data_qml['isMuted']:
                 pygame_channel = pygame_info['pygame_channel']
                 sound_obj = pygame_info['sound']
                 if not pygame_channel.get_busy():
                     if channel_data_qml['isRandom']:
                         self._schedule_next_random_play(channel_id)
                     else:
                         pygame_channel.play(sound_obj, loops=-1)
                         count_started += 1
        if count_started > 0: self._updateStatus("Started looping channels.")
        else: self._updateStatus("No looping channels needed starting (random scheduled).")
        self._check_playing_all_state() # Update state AFTER starting


    @Slot()
    def stopAll(self):
        print("Stopping all channels...")
        self._stopAllSounds()
        self._updateStatus("Stopped all channels.")
        self._check_playing_all_state() # Update state AFTER stopping


    @Slot()
    def openSettingsDialog(self):
        global default_preset_folder
        qapp_instance = QApplication.instance()
        if not qapp_instance:
             app_argv = sys.argv if hasattr(sys, 'argv') else []
             qapp_instance = QApplication(app_argv)

        selected_dir = QFileDialog.getExistingDirectory(
            None, "Select Default Preset Folder", default_preset_folder,
            QFileDialog.Option.ShowDirsOnly | QFileDialog.Option.DontResolveSymlinks
        )
        if selected_dir:
            if Path(selected_dir).is_dir():
                default_preset_folder = selected_dir
                save_settings()
                self._updateStatus(f"Default folder set to: {default_preset_folder}")
            else:
                 self._updateStatus("Invalid folder selected.")


    # --- Internal Helper Methods ---
    def _updateStatus(self, text):
        self._statusText = text
        self.statusTextChanged.emit(self._statusText)
        print(f"Status: {text}")

    def _find_and_set_cover_image(self):
        self._coverImagePath = ""
        if self._xml_preset_dir:
            for ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp']:
                 for filename in [f"cover{ext}", f"Cover{ext}"]:
                     cover_path = self._xml_preset_dir / filename
                     if cover_path.exists():
                         self._coverImagePath = str(cover_path.resolve())
                         break
                 if self._coverImagePath: break
        self.coverImagePathChanged.emit(self.coverImagePath)

    def _load_sound_for_channel(self, channel_id, relative_path):
        if not self._xml_preset_dir: return None
        normalized_relative_path = str(Path(relative_path))
        full_path = self._xml_preset_dir / normalized_relative_path
        if not full_path.exists():
            print(f"Sound file not found: {full_path}")
            return None
        try:
            sound = pygame.mixer.Sound(str(full_path))
            print(f"Successfully loaded sound: {full_path}")
            return sound
        except pygame.error as e:
            print(f"Error loading sound {full_path}: {e}")
            return None

    def _set_channel_volume_balance(self, channel_id, volume, balance):
        """ Internal: Sets volume/balance on the Pygame channel directly. Does NOT check mute state. """
        if channel_id not in self._active_pygame_channels: return

        pygame_channel = self._active_pygame_channels[channel_id]['pygame_channel']
        master_volume = max(0.0, min(1.0, float(volume) / 100.0))
        balance_norm = max(-1.0, min(1.0, float(balance) / 100.0))
        left_vol = master_volume * (1.0 - max(0, balance_norm))
        right_vol = master_volume * (1.0 + min(0, balance_norm))
        left_vol = max(0.0, min(1.0, left_vol))
        right_vol = max(0.0, min(1.0, right_vol))

        try:
            pygame_channel.set_volume(left_vol, right_vol)
            # print(f"DEBUG: Set Pygame Ch {channel_id} Vol/Bal -> L={left_vol:.2f} R={right_vol:.2f} (Master Vol: {master_volume:.2f})")
        except pygame.error as e:
            print(f"Error setting pygame volume/balance for Channel {channel_id}: {e}")

    def _apply_mute_state(self, channel_id, is_muted, initial_volume=None, initial_balance=None):
        """ Internal: Applies mute state by setting volume to 0 or restoring it. """
        if channel_id not in self._active_pygame_channels: return

        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml: return

        volume_to_restore = initial_volume if initial_volume is not None else channel_data_qml['volume']
        balance_to_restore = initial_balance if initial_balance is not None else channel_data_qml['balance']

        if is_muted:
            print(f"Applying Mute: Channel {channel_id} (setting vol to 0).")
            self._set_channel_volume_balance(channel_id, 0, 0) # Mute by setting volume to 0
        else:
            print(f"Applying Unmute: Channel {channel_id}. Restoring vol={volume_to_restore}, bal={balance_to_restore}")
            self._set_channel_volume_balance(channel_id, volume_to_restore, balance_to_restore)


    def _stopAllSounds(self):
        print("Stopping all sounds and timer...")
        self._random_timer.stop()
        pygame.mixer.stop()
        # Don't change mute state, just stop playback
        self._check_playing_all_state() # Update playing state


    def _check_playing_all_state(self):
         any_playing = any(info['pygame_channel'].get_busy() for info in self._active_pygame_channels.values())
         if self._is_playing_all != any_playing:
              self._is_playing_all = any_playing
              print(f"Emitting isPlayingAllChanged: {self._is_playing_all}")
              self.isPlayingAllChanged.emit(self._is_playing_all)


    def _schedule_next_random_play(self, channel_id):
        if channel_id not in self._active_pygame_channels: return
        channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
        if not channel_data_qml or not channel_data_qml['isRandom'] or channel_data_qml['isMuted']:
            self._active_pygame_channels[channel_id]['next_random_play_time'] = 0
            return

        unit_seconds = RANDOM_UNIT_SECONDS.get(channel_data_qml['randomUnit'], 3600)
        counter = max(1, channel_data_qml['randomCounter'])
        avg_interval = unit_seconds / counter
        random_delay = max(1.0, avg_interval * random.uniform(0.5, 1.5))
        next_play_timestamp = time.time() + random_delay
        self._active_pygame_channels[channel_id]['next_random_play_time'] = next_play_timestamp


    def _check_random_playback(self):
        current_time = time.time()
        for channel_id, pygame_info in list(self._active_pygame_channels.items()):
            channel_data_qml = next((ch for ch in self._channels if ch['channelId'] == channel_id), None)
            if not channel_data_qml or not channel_data_qml['isRandom'] or channel_data_qml['isMuted']:
                continue

            next_play_time = pygame_info.get('next_random_play_time', 0)

            if next_play_time > 0 and current_time >= next_play_time:
                pygame_channel = pygame_info['pygame_channel']
                sound_obj = pygame_info['sound']
                if not pygame_channel.get_busy():
                    print(f"Playing random sound for Channel {channel_id} ('{channel_data_qml['name']}')")
                    try:
                        # Apply current volume/balance just before playing
                        self._apply_mute_state(channel_id, False) # Ensures correct volume is set
                        pygame_channel.play(sound_obj, loops=0)
                        self._schedule_next_random_play(channel_id)
                        self._check_playing_all_state() # Update state
                    except pygame.error as e:
                        print(f"Error playing random sound for channel {channel_id}: {e}")
                        self._schedule_next_random_play(channel_id)
                else:
                    print(f"Channel {channel_id} busy, rescheduling random play.")
                    self._active_pygame_channels[channel_id]['next_random_play_time'] = current_time + random.uniform(1.0, 3.0)


    def cleanup(self):
        print("Cleaning up...")
        self._random_timer.stop()
        pygame.mixer.quit()
        pygame.quit()
        print("Pygame quit.")

# --- Main Application Execution ---
if __name__ == "__main__":
    app_argv = sys.argv if hasattr(sys, 'argv') else []
    app = QApplication(app_argv)

    engine = QQmlApplicationEngine()

    backend = PlayerBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = script_dir / "player_ui.qml"
    if not qml_file.exists():
         print(f"ERROR: QML file not found at {qml_file}", file=sys.stderr)
         placeholder_qml = """
import QtQuick; import QtQuick.Controls; ApplicationWindow {
visible: true; width: 300; height: 200; title: "Error";
Label { anchors.centerIn: parent; text: "Error: player_ui.qml not found!" } }"""
         try:
             with open(qml_file, "w") as f: f.write(placeholder_qml)
             print("Created placeholder player_ui.qml.")
         except Exception as e:
             print(f"ERROR: Could not create placeholder QML file: {e}", file=sys.stderr)
             sys.exit(1)

    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("ERROR: Could not load QML file. Check for QML errors in console output.", file=sys.stderr)
        sys.exit(-1)

    if backend: app.aboutToQuit.connect(backend.cleanup)

    print("Starting application event loop...")
    sys.exit(app.exec())
