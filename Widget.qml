// Copyright (c) Joseph Hale, 2026
// SPDX-License-Identifier: MPL-2.0

import QtQuick
import qs.Commons
import qs.Ui

// A bar widget that greets someone. Replace the body with your own.
BarWidget {
  id: root
  moduleName: "thehale.plugin" // Must match `id` in manifest.json

  // Overrides come from this widget's entry in shell.json's bar.layout
  readonly property string who: setting("name", "World")
  readonly property string greeting: "Hello, " + who + "!"

  implicitWidth: label.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: barSize

  Text {
    id: label
    anchors.centerIn: parent
    text: root.greeting
    textFormat: Text.PlainText
    color: root.bar ? root.bar.barForeground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }
}
