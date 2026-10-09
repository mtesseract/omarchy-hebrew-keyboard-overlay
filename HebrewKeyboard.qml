import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Keymap.js" as Keymap

// Shows the Hebrew keyboard layout of the active Hyprland keyboard. It slides up
// on the focused monitor, never takes keyboard focus, and can be dragged; the
// position is kept across sessions.
Item {
  id: root

  // Host contract: the shell's toggle() reads `opened` and calls open()/close().
  property bool opened: false
  // The keyboard is on screen: true while open and while the slide-out plays.
  property bool shown: false

  // Width of the overlay as a fraction of the monitor width.
  property real widthFraction: 0.72
  // Gap between the default position and the bottom edge of the monitor.
  property int bottomMargin: 24
  property int slideInDuration: 150
  property int slideOutDuration: 150

  // Set by the shell when it loads the plugin.
  property var shell: null
  property var manifest: null

  // This plugin's entry in ~/.config/omarchy/shell.json, where its settings live:
  //   keyboard: the physical keyboard, a file name in keyboards/: "ansi"
  //             (default) or "iso"
  //   labels:   layout printed on the keycaps, e.g. "us" for Dvorak on QWERTY
  //             keycaps; defaults to the configured non-Hebrew layout
  readonly property var settings: {
    var plugins = root.shell && root.shell.shellConfig ? root.shell.shellConfig.plugins : null
    var id = root.manifest ? root.manifest.id : ""
    return (plugins || []).filter(function(p) { return p && p.id === id })[0] || {}
  }
  readonly property string keyboardType: root.settings.keyboard || ""
  readonly property string labelSpec: root.settings.labels || (root.layout ? root.layout.labels : "")

  property var layout: null     // Keymap.hebrewLayout()
  property var hebrew: null     // Keymap.parseSymbols() of the il layout
  property var labels: null     // the same for the keycap labels
  property var keysyms: null    // Keymap.parseKeysyms()
  property var characters: null  // Keymap.characters()
  property var theme: ({})      // Keymap.parseColors() of the current theme
  property bool keysymsMissing: false
  // The label layout changed while its keymap was being read; that result is
  // for the old layout.
  property bool labelsOutdated: false

  readonly property var colors: ({
    card: theme.darker_background || theme.background || "#101315",
    key: theme.background || "#101315",
    letterKey: theme.lighter_background || theme.background || "#101315",
    border: theme.muted || "#707880",
    text: theme.foreground || "#cacccc",
    name: theme.bright_foreground || theme.foreground || "#cacccc",
    label: theme.muted || "#707880",
    shift: theme.accent || "#cacccc",
    altgr: theme.bright_yellow || theme.yellow || theme.accent || "#cacccc"
  })

  // Top-left corner of the overlay on its monitor, kept across sessions.
  property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/hebrew-keyboard-overlay.json"
  property var savedPosition: null

  // The surface stays mapped while hidden (empty and click-through). Mapping it
  // on open would play Hyprland's layer fade over the slide-in.
  property var targetScreen: null

  Component.onCompleted: root.targetScreen = root.focusedScreen()

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === name) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  function open(payload) {
    root.opened = true
    if (root.keysymsMissing) {
      root.fail("cannot read /usr/include/xkbcommon/xkbcommon-keysyms.h (from libxkbcommon)")
      return
    }
    colorsFile.reload()
    if (!devicesProc.running) devicesProc.running = true
    // Show the previous layout right away; the fresh one replaces it when
    // ready. The first open of a session waits for it.
    if (root.characters) root.slideIn()
  }

  function close() {
    root.opened = false
    if (!root.shown) return
    slideInAnimation.stop()
    slideOutAnimation.from = card.y
    slideOutAnimation.to = panel.height
    slideOutAnimation.start()
  }

  // Logs a problem and shows it as a desktop notification.
  function report(message) {
    console.warn("hebrew-keyboard-overlay: " + message)
    Quickshell.execDetached(["notify-send", "-a", "Hebrew Keyboard Overlay", "Hebrew keyboard overlay", message])
  }

  // Reports why the overlay can't be shown and gives up on this open, so the
  // host doesn't count an overlay that never appeared as open. When reopening,
  // the previous keyboard may already be on screen; it slides away.
  function fail(message) {
    root.report(message)
    if (root.shown) root.close()
    else root.opened = false
  }

  function layoutLoaded(devicesJson) {
    try {
      root.layout = Keymap.hebrewLayout(devicesJson)
    } catch (e) {
      root.fail("cannot read the output of hyprctl devices -j")
      return
    }
    if (!root.layout) {
      root.fail("no Hebrew (il) layout in Hyprland's kb_layout")
      return
    }
    var command = ["xkbcli", "compile-keymap", "--layout", "il"]
    if (root.layout.variant) command.push("--variant", root.layout.variant)
    if (root.layout.options) command.push("--options", root.layout.options)
    hebrewProc.command = command
    hebrewProc.running = true
  }

  function update() {
    if (!root.hebrew || !root.labels || !root.keysyms) return
    root.characters = Keymap.characters(root.hebrew, root.labels, root.keysyms)
    if (root.opened && !root.shown) root.slideIn()
  }

  onLabelSpecChanged: root.loadLabels()

  function loadLabels() {
    if (!root.labelSpec) return
    if (labelsProc.running) {
      root.labelsOutdated = true
      return
    }
    var spec = Keymap.parseLayout(root.labelSpec)
    var command = ["xkbcli", "compile-keymap", "--layout", spec.layout]
    if (spec.variant) command.push("--variant", spec.variant)
    labelsProc.command = command
    labelsProc.running = true
  }

  function slideIn() {
    slideOutAnimation.stop()
    var screen = root.focusedScreen()
    if (!root.shown && screen && screen !== root.targetScreen) {
      // Moving the surface to another monitor remaps it; wait for that.
      root.targetScreen = screen
      slideInStart.interval = 250
    } else {
      slideInStart.interval = 1
    }
    root.shown = true
    slideInStart.restart()
  }

  // The resting position depends on the surface size, so wait until the
  // compositor has sized it.
  function startSlideIn() {
    if (!root.opened) return
    if (panel.width <= 0 || panel.height <= 0) {
      slideInStart.restart()
      return
    }
    var pos = root.restingPosition()
    card.x = pos.x
    slideInAnimation.stop()
    slideInAnimation.from = card.y >= 0 && card.y < panel.height ? card.y : panel.height
    slideInAnimation.to = pos.y
    slideInAnimation.start()
  }

  Timer {
    id: slideInStart
    interval: 1
    onTriggered: root.startSlideIn()
  }

  // The saved position clamped to the monitor, else centered above the bottom edge.
  function restingPosition() {
    var maxX = Math.max(0, panel.width - card.width)
    var maxY = Math.max(0, panel.height - card.height)
    var p = root.savedPosition
    if (p && typeof p.x === "number" && typeof p.y === "number")
      return { x: Math.min(Math.max(0, p.x), maxX), y: Math.min(Math.max(0, p.y), maxY) }
    return { x: maxX / 2, y: Math.max(0, maxY - root.bottomMargin) }
  }

  function savePosition() {
    root.savedPosition = { x: Math.round(card.x), y: Math.round(card.y) }
    stateFile.setText(JSON.stringify(root.savedPosition))
  }

  Region { id: cardRegion; item: card }
  Region { id: emptyRegion }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try { root.savedPosition = JSON.parse(text()) } catch (e) { root.savedPosition = null }
    }
  }

  FileView {
    id: colorsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: root.theme = Keymap.parseColors(text())
  }

  FileView {
    path: "/usr/include/xkbcommon/xkbcommon-keysyms.h"
    printErrors: false
    onLoaded: {
      root.keysyms = Keymap.parseKeysyms(text())
      root.update()
    }
    onLoadFailed: root.keysymsMissing = true
  }

  Command {
    id: devicesProc
    command: ["hyprctl", "devices", "-j"]
    onFailedToStart: root.fail("cannot run hyprctl")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutLoaded(text)
    }
  }

  Command {
    id: hebrewProc
    onFailedToStart: root.fail("cannot run xkbcli (from libxkbcommon)")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var symbols = Keymap.parseSymbols(text)
        if (Object.keys(symbols).length === 0) {
          root.fail("xkbcli compile-keymap returned no keymap for the il layout")
          return
        }
        root.hebrew = symbols
        root.update()
      }
    }
  }

  Command {
    id: labelsProc
    // hebrewProc runs the same program and reports it.
    onFailedToStart: root.labels = ({})
    onExited: {
      if (!root.labelsOutdated) return
      root.labelsOutdated = false
      Qt.callLater(root.loadLabels)
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.labelsOutdated) return
        // Without labels the keyboard is still useful, so draw it without them.
        root.labels = Keymap.parseSymbols(text)
        if (Object.keys(root.labels).length === 0)
          root.report("no keymap for the label layout " + root.labelSpec + "; showing the keys without labels")
        root.update()
      }
    }
  }

  PanelWindow {
    id: panel
    visible: true
    screen: root.targetScreen
    // Full-screen and fixed-size; the keyboard moves inside it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "hebrew-keyboard-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Click-through except for the keyboard, and entirely while hidden.
    mask: root.shown ? cardRegion : emptyRegion

    Item {
      id: card
      width: Math.round(panel.width * root.widthFraction)
      height: Math.round(width * keyboard.height / keyboard.width)
      y: panel.height
      visible: root.shown

      Keyboard {
        id: keyboard
        characters: root.characters || ({})
        keyboardType: root.keyboardType
        colors: root.colors
        variant: root.layout ? root.layout.variant : ""
        level3Key: Keymap.level3Key(root.layout ? root.layout.options : "")
        scale: card.width / width
        transformOrigin: Item.TopLeft
        onProblem: function(message) { root.report(message) }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.colors.border
        border.width: 1
      }

      // Dragging moves the keyboard; the position is saved only after a drag.
      // A press finishes the slide-in, and the keyboard ignores the mouse while
      // it slides out.
      MouseArea {
        property bool dragged: false
        anchors.fill: parent
        enabled: root.opened
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: card
        drag.minimumX: 0
        drag.maximumX: panel.width - card.width
        drag.minimumY: 0
        drag.maximumY: panel.height - card.height
        drag.threshold: 2
        onPressed: {
          dragged = false
          if (slideInAnimation.running) slideInAnimation.complete()
        }
        onPositionChanged: if (drag.active) dragged = true
        onReleased: if (dragged) root.savePosition()
      }
    }

    NumberAnimation {
      id: slideInAnimation
      target: card
      property: "y"
      duration: root.slideInDuration
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      id: slideOutAnimation
      target: card
      property: "y"
      duration: root.slideOutDuration
      easing.type: Easing.OutCubic
      onFinished: if (!root.opened) root.shown = false
    }
  }
}
