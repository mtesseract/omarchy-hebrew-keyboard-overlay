import QtQuick

// Draws rows of keys. `rows` comes from a file in keyboards/ and describes the
// physical keyboard: per row, how many key widths its first key is indented from
// the left edge, and its keys as xkb key names.
Item {
  id: keyRows

  required property var rows       // [{ indent, keys: ["AE01", …] }, …]
  property var wideKeys: []        // keys 1.5 key widths wide
  required property var characters // Keymap.characters()
  required property var colors     // see Keyboard.qml
  required property int unit
  required property int gap
  required property int namesHeight

  Repeater {
    model: keyRows.rows

    Repeater {
      id: row
      required property var modelData
      required property int index
      model: modelData.keys

      Key {
        required property string modelData
        required property int index
        entry: keyRows.characters[modelData] || ({})
        wide: keyRows.wideKeys.indexOf(modelData) >= 0
        colors: keyRows.colors
        unit: keyRows.unit
        gap: keyRows.gap
        namesHeight: keyRows.namesHeight
        x: (row.modelData.indent + index) * keyRows.unit
        y: row.index * (keyRows.unit + keyRows.namesHeight)
      }
    }
  }
}
