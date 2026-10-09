import QtQuick

// One key. Sizes are in the keyboard's design units (see Keyboard.qml); the
// legends are placed by their baselines.
Item {
  id: key

  required property var entry    // from Keymap.characters()
  property bool wide: false
  required property var colors   // see Keyboard.qml
  property int unit: 76
  property int gap: 6
  property int namesHeight: 24

  // Top of the area below the names band.
  readonly property int faceTop: namesHeight
  readonly property int faceHeight: unit - gap
  readonly property string hebrewFont: "Noto Sans Hebrew"
  readonly property string latinFont: "JetBrainsMono Nerd Font"
  readonly property color face: entry.letter ? colors.letterKey : colors.key

  width: (wide ? 1.5 * unit : unit) - gap
  height: faceHeight + namesHeight

  Rectangle {
    anchors.fill: parent
    color: key.face
    border.color: key.colors.border
    border.width: 1
  }

  // Names of the letter and of the AltGr character, in the band at the top.
  Column {
    y: 3
    width: parent.width
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: text !== ""
      text: key.entry.baseName || ""
      color: key.colors.name
      font { family: "Noto Sans"; pixelSize: 10; weight: Font.Medium }
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: text !== ""
      text: key.entry.altgrName || ""
      color: key.colors.altgr
      font { family: "Noto Sans"; pixelSize: 10; weight: Font.Medium }
    }
  }

  // The physical key, bottom-left.
  Text {
    x: 8
    y: key.faceTop + key.faceHeight - 8 - baselineOffset
    text: key.entry.label || ""
    color: key.colors.label
    font { family: key.latinFont; pixelSize: 13 }
  }

  // The Hebrew character; moved left when a niqqud takes the right half.
  Text {
    x: (key.entry.mark ? key.width * 0.3 : key.width / 2) - implicitWidth / 2
    y: key.faceTop + 44 - baselineOffset
    text: key.entry.base || ""
    color: key.colors.text
    font {
      family: key.hebrewFont
      pixelSize: key.entry.letter ? 32 : 24
      weight: key.entry.letter ? Font.DemiBold : Font.Normal
    }
  }

  // Shift level, top-right, or top-left when a niqqud above its ◌ is there.
  Text {
    readonly property bool atLeft: key.entry.mark === true && key.entry.markPosition === "above"
    x: atLeft ? 8 : key.width - 8 - implicitWidth
    y: key.faceTop + 18 - baselineOffset
    visible: text !== ""
    text: key.entry.shift || ""
    color: key.colors.shift
    font { family: key.hebrewFont; pixelSize: 14 }
  }

  // AltGr level other than a niqqud, small in the bottom-right corner.
  Text {
    x: key.width - 8 - implicitWidth
    y: key.faceTop + key.faceHeight - 8 - baselineOffset
    visible: !key.entry.mark && text !== ""
    text: key.entry.altgr || ""
    color: key.colors.altgr
    font { family: key.hebrewFont; pixelSize: 15 }
  }

  // A niqqud, large in the right half on a dimmed ◌. The whole character is
  // drawn in the AltGr color, then its ◌ is painted over in the key color and
  // drawn again dimmed. The baseline keeps marks above or below the ◌ inside
  // the key.
  Item {
    id: niqqud
    visible: key.entry.mark === true
    anchors.fill: parent
    readonly property real markBaseline: key.faceTop
      + (key.entry.markPosition === "above" ? 60 : key.entry.markPosition === "inside" ? 52 : 50)

    Text {
      id: markText
      // Right-aligned by the ◌ alone; Qt counts the mark into implicitWidth.
      x: key.width + 2 - carrier.implicitWidth
      y: niqqud.markBaseline - baselineOffset
      text: "◌" + (key.entry.altgr || "")
      color: key.colors.altgr
      font { family: key.hebrewFont; pixelSize: 54 }
    }
    Text {
      x: markText.x
      y: markText.y
      text: "◌"
      color: key.face
      style: Text.Outline
      styleColor: key.face
      font: markText.font
    }
    Text {
      id: carrier
      x: markText.x
      y: markText.y
      text: "◌"
      color: key.colors.border
      font: markText.font
    }
  }
}
