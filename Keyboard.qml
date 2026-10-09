import QtQuick

// The whole keyboard at its design size; HebrewKeyboard.qml scales it to fit.
Item {
  id: keyboard

  required property var characters // Keymap.characters()
  required property string keyboardType  // a file name in keyboards/, e.g. "iso"
  required property var colors     // card, key, letterKey, border, text, name, label, shift, altgr
  required property string variant
  required property string level3Key

  // A problem worth telling the user about, e.g. an unknown keyboard type.
  signal problem(string message)

  readonly property int unit: 76
  readonly property int gap: 6
  readonly property int padding: 28
  readonly property int namesHeight: 24
  readonly property int headerHeight: 30

  width: padding * 2 + 15 * unit - gap
  height: padding * 2 + headerHeight + 4 * (unit + namesHeight) - gap

  Rectangle {
    anchors.fill: parent
    color: keyboard.colors.card
  }

  // Which corner color is which level; starts with the layout variant if one is set.
  Row {
    id: legend
    x: keyboard.padding
    y: keyboard.padding + 8 - shiftLegend.baselineOffset
    spacing: 0
    Text {
      visible: keyboard.variant !== ""
      text: "il(" + keyboard.variant + ")   ·   "
      color: keyboard.colors.label
      font: shiftLegend.font
    }
    Text {
      id: shiftLegend
      text: "shift"
      color: keyboard.colors.shift
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
    }
    Text {
      text: " · "
      color: keyboard.colors.label
      font: shiftLegend.font
    }
    Text {
      text: keyboard.level3Key
      color: keyboard.colors.altgr
      font: shiftLegend.font
    }
  }

  // The physical keyboard: keyboards/<keyboardType>.qml lists its rows of keys.
  // Each file there is one keyboard type; an unknown type falls back to ANSI.
  Loader {
    id: geometry
    readonly property bool known: /^[a-z0-9-]+$/.test(keyboard.keyboardType) && !failed
    property bool failed: false
    visible: false
    source: "keyboards/" + (known ? keyboard.keyboardType : "ansi") + ".qml"
    onStatusChanged: {
      if (status !== Loader.Error) return
      keyboard.problem("keyboards/" + keyboard.keyboardType + ".qml could not be loaded, using ansi")
      failed = true
    }
  }

  Connections {
    target: keyboard
    function onKeyboardTypeChanged() { geometry.failed = false }
  }

  KeyRows {
    x: keyboard.padding
    y: keyboard.padding + keyboard.headerHeight
    rows: geometry.item ? geometry.item.rows : []
    wideKeys: geometry.item && geometry.item.wideKeys ? geometry.item.wideKeys : []
    characters: keyboard.characters
    colors: keyboard.colors
    unit: keyboard.unit
    gap: keyboard.gap
    namesHeight: keyboard.namesHeight
  }
}
