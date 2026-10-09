import QtQuick

// ISO keyboard (most of Europe): an extra key (<LSGT>) between left Shift and Z,
// and the backslash key (<BKSL>) at the end of the home row, next to Enter.
//
// Indents are in key widths and come from the keys left of each row, which are
// not drawn: Tab 1.5, Caps Lock 1.75, left Shift 1.25.
Item {
  readonly property var rows: [
    { indent: 0, keys: ["TLDE", "AE01", "AE02", "AE03", "AE04", "AE05", "AE06", "AE07", "AE08", "AE09", "AE10", "AE11", "AE12"] },
    { indent: 1.5, keys: ["AD01", "AD02", "AD03", "AD04", "AD05", "AD06", "AD07", "AD08", "AD09", "AD10", "AD11", "AD12"] },
    { indent: 1.75, keys: ["AC01", "AC02", "AC03", "AC04", "AC05", "AC06", "AC07", "AC08", "AC09", "AC10", "AC11", "BKSL"] },
    { indent: 1.25, keys: ["LSGT", "AB01", "AB02", "AB03", "AB04", "AB05", "AB06", "AB07", "AB08", "AB09", "AB10"] }
  ]
}
