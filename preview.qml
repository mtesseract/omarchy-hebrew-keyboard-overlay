import Quickshell
import QtQuick

// Runs the overlay outside omarchy-shell and opens it: qs -p preview.qml
// Settings for the preview go in the plugins entry below.
ShellRoot {
  HebrewKeyboard {
    id: overlay
    manifest: ({ id: "preview" })
    shell: ({ shellConfig: { plugins: [{ id: "preview" }] } })  // e.g. keyboard: "iso", labels: "de"
  }
  Timer { interval: 300; running: true; onTriggered: overlay.open("") }
}
