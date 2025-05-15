import QtQuick
import QtQuick.Controls // Required for controls like Button, Slider, CheckBox, MenuBar, ToolBar, ScrollBar, TextField, GroupBox, ComboBox, RadioButton
import QtQuick.Layouts // Required for RowLayout, ColumnLayout, GridLayout
import QtQuick.Controls.Material // Import Material style

ApplicationWindow {
    id: rootWindow
    visible: true
    width: 1440
    height: 800
    title: "Ambient Mixer Player"
    // color: "#f0f0f0" // Background handled by Material theme

    // Apply Material style
    Material.theme: Material.Dark // Or Material.Light
    // Material.accent: Material.Blue

    font.pointSize: 10

    // --- Header ---
    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            spacing: 5

            Button {
                id: loadButton
                icon.name: "document-open"
                ToolTip.text: "Load Preset"
                onClicked: backend.loadPreset()
                ToolTip.visible: hovered
                text: "Load Preset"
            }

            Button {
                id: playStopAllButton
                icon.name: backend.isPlayingAll ? "media-playback-stop" : "media-playback-start"
                ToolTip.text: backend.isPlayingAll ? "Stop All Channels" : "Play All Channels"
                text: backend.isPlayingAll ? "Stop All Channels" : "Play All Channels"
                enabled: backend.channelModel.length > 0
                ToolTip.visible: hovered
                onClicked: {
                    if (backend.isPlayingAll) {
                        backend.stopAll();
                    } else {
                        backend.playAll();
                    }
                }
                Layout.alignment: Qt.AlignVCenter
                Connections {
                     target: backend
                     function onIsPlayingAllChanged(isPlayingAll) {
                         playStopAllButton.icon.name = isPlayingAll ? "media-playback-stop" : "media-playback-start";
                         playStopAllButton.ToolTip.text = isPlayingAll ? "Stop All Channels" : "Play All Channels";
                         // Update button text as well
                         playStopAllButton.text = isPlayingAll ? "Stop All Channels" : "Play All Channels";
                     }
                     function onChannelsChanged() {
                          playStopAllButton.icon.name = backend.isPlayingAll ? "media-playback-stop" : "media-playback-start";
                          playStopAllButton.ToolTip.text = backend.isPlayingAll ? "Stop All Channels" : "Play All Channels";
                          // Update button text as well
                          playStopAllButton.text = backend.isPlayingAll ? "Stop All Channels" : "Play All Channels";
                     }
                 }
            }

            Label { Layout.fillWidth: true } // Spacer

        }
    }

    menuBar: MenuBar {
        Menu {
            title: "&Settings"
            Action { text: "Set Default Folder..."; onTriggered: backend.openSettingsDialog() }
            MenuSeparator {}
            Action { text: "E&xit"; onTriggered: Qt.quit() }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 5
        spacing: 15

        Frame {
            id: topSection
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Material.elevation: 2
            background: Rectangle {
                 color: Material.background
                 radius: 4
            }

            RowLayout {
                width: parent.width
                height: parent.height
                spacing: 10
                anchors.margins: 5


                Rectangle { // Image Placeholder
                    id: imagePlaceholder
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 160
                    color: coverImage.status === Image.Ready ? "transparent" : "#666"

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: backend.coverImagePath
                        fillMode: Image.PreserveAspectCrop; clip: true; smooth: true
                        visible: status === Image.Ready
                    }

                    Label {
                        visible: coverImage.status !== Image.Ready
                        anchors.centerIn: parent
                        text: coverImage.status === Image.Error ? "Error" : "No Cover"
                        color: Material.secondaryTextColor; font.italic: true
                    }
                }

                ColumnLayout { // Title/Description Column
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Label {
                        id: titleLabel
                        text: backend.title
                        font.pointSize: 18; font.bold: true;
                        color: Material.primaryTextColor
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        background: Rectangle { color: "transparent" }
                        Label {
                            id: descriptionLabel
                            text: backend.description
                            wrapMode: Text.WordWrap;
                            color: Material.secondaryTextColor;
                            font.pointSize: 10
                            padding: 2
                        }
                    }
                }
            }
        }

        Flickable {
            id: channelScrollView
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: channelRowLayout.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick

             ScrollBar.horizontal: ScrollBar { }


            RowLayout {
                id: channelRowLayout
                spacing: 4

                Repeater {
                    model: backend.channelModel

                    Frame {
                        id: channelDelegateContainer
                        width: 150
                        implicitHeight: 510
                        Material.elevation: 1
                        padding: 0

                        background: Rectangle {
                             color: modelData.isLoaded ? (Material.theme === Material.Dark ? "#333" : "#fff") : (Material.theme === Material.Dark ? "#222" : "#f5f5f5")
                             border.color: Material.dividerColor
                             radius: 4
                        }


                        ColumnLayout {
                            id: delegateContentLayout
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 4

                            Column { // Title/ID Column
                                spacing: 1
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Label {
                                    text: "Channel " + (modelData.channelId + 1)
                                    font.pointSize: 8; color: Material.hintTextColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    text: modelData.name
                                    font.pointSize: 9; color: Material.primaryTextColor
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                }
                            }

                            Item { // Balance Slider Container
                                Layout.fillWidth: true; height: balanceRow.implicitHeight * 0.9
                                Layout.alignment: Qt.AlignHCenter
                                RowLayout {
                                    id: balanceRow; width: parent.width
                                    Label { text: "L"; font.bold: true; color: Material.secondaryTextColor }
                                    Slider {
                                        id: balanceSlider_delegate
                                        from: -100; to: 100; value: modelData.balance
										Layout.fillWidth: true;
                                        live: true;
                                        enabled: modelData.isLoaded
                                        onValueChanged: backend.setBalance(modelData.channelId, value)
                                        Component.onCompleted: value = modelData.balance
                                        ToolTip.visible: pressed; ToolTip.text: value.toFixed(0)
                                    }
                                    Label { text: "R"; font.bold: true; color: Material.secondaryTextColor }
                                }
                            }

                            Item { // Volume Slider Container
                                Layout.fillWidth: true
                                height: volumeSliderItem.height + volumeLabel.implicitHeight + 5
                                Layout.alignment: Qt.AlignHCenter
                                Label {
                                     id: volumeLabel
                                     text: "Volume: " + volumeSliderV.value.toFixed(0)
                                     anchors.top: parent.top
                                     anchors.horizontalCenter: parent.horizontalCenter
                                     color: Material.primaryTextColor
                                }
                                Item {
                                     id: volumeSliderItem; width: 30; height: 100
                                     anchors.horizontalCenter: parent.horizontalCenter
                                     anchors.top: volumeLabel.bottom; anchors.topMargin: 3
                                     Slider {
                                         id: volumeSliderV
                                         anchors.fill: parent
                                         orientation: Qt.Vertical
                                         from: 0; to: 100
                                         value: modelData.volume; live: true
                                         enabled: modelData.isLoaded
                                         onValueChanged: backend.setVolume(modelData.channelId, value)
                                         Component.onCompleted: value = modelData.volume
                                         ToolTip.visible: pressed; ToolTip.text: value.toFixed(0)
                                     }
                                }
                            }

                            GroupBox { // Playback Mode Controls
                                title: "Playback Mode"; Layout.fillWidth: true
                                ColumnLayout {
                                    width: parent.width
                                    CheckBox {
                                        id: randomCheckBox; text: "Random Intervals"
                                        checked: modelData.isRandom; enabled: modelData.isLoaded
                                        onClicked: backend.setRandomEnabled(modelData.channelId, checked)
                                    }
                                    // *** Container for Random controls, now always visible but enabled based on checkbox ***
                                    ColumnLayout {
                                        // visible: randomCheckBox.checked // Removed visibility binding
                                        enabled: randomCheckBox.checked && modelData.isLoaded // Keep enabled binding
                                        spacing: 1
                                        Layout.fillWidth: true

                                        RowLayout { // Count Row
                                            spacing: 1
                                            Label { text: "Count:"; color: Material.primaryTextColor; font.pointSize: 9 }
                                            TextField {
                                                id: counterTextField
                                                text: modelData.randomCounter.toString()
                                                Layout.preferredWidth: 45
												Layout.preferredHeight: 36
                                                horizontalAlignment: Text.AlignRight
                                                font.pointSize: 9
                                                validator: IntValidator { bottom: 1; top: 99; }
                                                onEditingFinished: {
                                                    var count = parseInt(text);
                                                    if (!isNaN(count)) {
                                                        backend.setRandomCounter(modelData.channelId, count);
                                                    } else {
                                                        text = modelData.randomCounter.toString();
                                                    }
                                                }
                                                Connections {
                                                     target: backend
                                                     function onChannelPropsChanged(channelId, propName, propValue) {
                                                         if (channelId === modelData.channelId && propName === "randomCounter") {
                                                             counterTextField.text = propValue.toString();
                                                         }
                                                     }
                                                }
                                            }
                                            Label { text: "per"; color: Material.primaryTextColor; font.pointSize: 9 }
                                        } // End Count Row

                                        RowLayout {
                                            spacing: 2
                                            Label { text: "Unit:"; verticalAlignment: Text.AlignVCenter; color: Material.primaryTextColor; font.pointSize: 9 }
                                            ComboBox {
                                                 id: unitComboBox
                                                 Layout.preferredWidth: 36
												 Layout.preferredHeight: 36
                                                 font.pointSize: 6
                                                 model: ["s", "m", "h"] // Display text
                                                 // Function to map backend value ('s','m','h') to index
                                                 function updateIndexFromModel() {
                                                     if (modelData.randomUnit === 's') currentIndex = 0;
                                                     else if (modelData.randomUnit === 'm') currentIndex = 1;
                                                     else currentIndex = 2; // Default to 'h'
                                                 }
                                                 Component.onCompleted: updateIndexFromModel() // Set initial index

                                                 // Send 's', 'm', or 'h' back to backend
                                                 onCurrentIndexChanged: {
                                                     var unitChar = 'h'; // Default
                                                     if (currentIndex === 0) unitChar = 's';
                                                     else if (currentIndex === 1) unitChar = 'm';
                                                     backend.setRandomUnit(modelData.channelId, unitChar);
                                                 }
                                                 // Update index if backend changes the value
                                                 Connections {
                                                     target: backend
                                                     function onChannelPropsChanged(channelId, propName, propValue) {
                                                         if (channelId === modelData.channelId && propName === "randomUnit") {
                                                             unitComboBox.updateIndexFromModel();
                                                         }
                                                     }
                                                 }
                                            } // End ComboBox
                                        } // End Unit Row

                                    } // End Random Controls Container
                                }
                            } // End Playback Mode GroupBox

                            // Mute Button Container
                            Item {
                                Layout.preferredWidth: 36
								Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignHCenter
                                Button {
                                    id: muteButton
                                    anchors.centerIn: parent
                                    icon.name: modelData.isMuted ? "audio-volume-muted" : "audio-volume-high"
                                    enabled: modelData.isLoaded
                                    ToolTip.text: modelData.isMuted ? "Unmute Channel" : "Mute Channel"
                                    ToolTip.visible: hovered
                                    Layout.preferredWidth: 100
								    Layout.preferredHeight: 36
                                    flat: true
                                     Connections {
                                         target: backend
                                         function onChannelPropsChanged(channelId, propName, propValue) {
                                             if (channelId === modelData.channelId && propName === "isMuted") {
                                                 // muteButton.checked = propValue; // Removed checkable
                                                 muteButton.icon.name = propValue ? "audio-volume-muted" : "audio-volume-high";
                                                 muteButton.ToolTip.text = propValue ? "Unmute Channel" : "Mute Channel";
                                             }
                                         }
                                    }
                                }
                            } // End Mute Button Container
                        } // End Inner ColumnLayout for controls
                    } // End Delegate Frame
                } // End Repeater
            } // End Channel RowLayout
        } // End Channel Flickable

    } // End Main ColumnLayout

    onClosing: { console.log("QML Window closing signal received.") }
}
