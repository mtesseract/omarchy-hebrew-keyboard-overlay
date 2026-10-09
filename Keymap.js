.pragma library

// Parsing and lookups for HebrewKeyboard.qml. Everything here is a pure function
// of the text it is given.

// Where each mark sits relative to its letter; marks not listed sit below.
// Unicode doesn't say: Hebrew points have fixed-position combining classes
// (10-26) rather than above (230) / below (220).
var NIQQUD_ABOVE = "ֹֺֿׁׂ֫"  // ole, holam, holam haser, rafe, shin/sin dot
var NIQQUD_INSIDE = "ּ"  // dagesh / mapiq

// xkb lv3:* option -> the key it makes the third-level (AltGr) key
var LEVEL3_KEYS = {
  "ralt_switch": "right alt", "ralt_switch_multikey": "right alt",
  "lalt_switch": "left alt", "alt_switch": "either alt", "switch": "right ctrl",
  "menu_switch": "menu", "win_switch": "super", "lwin_switch": "left super",
  "rwin_switch": "right super", "caps_switch": "caps lock", "bksl_switch": "backslash",
  "lsgt_switch": "< > key", "enter_switch": "keypad enter", "tab_switch": "tab"
}

var NAMES = {
  "\u05d0": "alef",
  "\u05d1": "bet",
  "\u05d2": "gimel",
  "\u05d3": "dalet",
  "\u05d4": "he",
  "\u05d5": "vav",
  "\u05d6": "zayin",
  "\u05d7": "het",
  "\u05d8": "tet",
  "\u05d9": "yod",
  "\u05da": "final kaf",
  "\u05db": "kaf",
  "\u05dc": "lamed",
  "\u05dd": "final mem",
  "\u05de": "mem",
  "\u05df": "final nun",
  "\u05e0": "nun",
  "\u05e1": "samekh",
  "\u05e2": "ayin",
  "\u05e3": "final pe",
  "\u05e4": "pe",
  "\u05e5": "final tsadi",
  "\u05e6": "tsadi",
  "\u05e7": "qof",
  "\u05e8": "resh",
  "\u05e9": "shin",
  "\u05ea": "tav",
  "\u05b0": "sheva",
  "\u05b1": "hataf segol",
  "\u05b2": "hataf patah",
  "\u05b3": "hataf qamats",
  "\u05b4": "hiriq",
  "\u05b5": "tsere",
  "\u05b6": "segol",
  "\u05b7": "patah",
  "\u05b8": "qamats",
  "\u05b9": "holam",
  "\u05ba": "holam haser for vav",
  "\u05bb": "qubuts",
  "\u05bc": "dagesh",
  "\u05bd": "meteg",
  "\u05bf": "rafe",
  "\u05c1": "shin dot",
  "\u05c2": "sin dot",
  "\u05c4": "upper dot",
  "\u05c7": "qamats qatan",
  "\u05ab": "ole",
  "\u05be": "maqaf",
  "\u05c0": "paseq",
  "\u05c3": "sof pasuq",
  "\u05c6": "nun hafukha",
  "\u05f0": "double vav",
  "\u05f1": "vav yod",
  "\u05f2": "double yod",
  "\u05f3": "geresh",
  "\u05f4": "gershayim",
  "\u20aa": "shekel"
}

// "de(nodeadkeys)" -> {layout: "de", variant: "nodeadkeys"}
function parseLayout(spec) {
  var m = /^\s*([^(\s]+)\s*(?:\(([^)]*)\))?\s*$/.exec(String(spec || ""))
  return m ? { layout: m[1], variant: m[2] || "" } : { layout: "us", variant: "" }
}

// From the main keyboard in `hyprctl devices -j` output: the variant and
// options of its il entry, and its first other layout as "layout(variant)",
// which the keycap labels default to. Null without an il entry.
function hebrewLayout(devicesJson) {
  var keyboards = (JSON.parse(devicesJson) || {}).keyboards || []
  var kb = keyboards.filter(function(k) { return k.main })[0] || keyboards[0]
  if (!kb) return null
  var layouts = String(kb.layout || "").split(",").map(function(l) { return l.trim() })
  var variants = String(kb.variant || "").split(",").map(function(v) { return v.trim() })
  var il = layouts.indexOf("il")
  if (il < 0) return null
  var other = layouts.findIndex(function(l) { return l && l !== "il" })
  return {
    variant: variants[il] || "",
    options: kb.options || "",
    labels: other < 0 ? "us" : layouts[other] + (variants[other] ? "(" + variants[other] + ")" : "")
  }
}

// key name -> list of keysym names per level, from `xkbcli compile-keymap` output.
function parseSymbols(keymap) {
  var text = keymap.slice(keymap.indexOf("xkb_symbols"))
  var keys = {}
  var re = /key <(\w+)>\s*{([\s\S]*?)};/g
  var m
  while ((m = re.exec(text)) !== null) {
    var levels = /=\s*\[([^\]]*)\]/.exec(m[2]) || /\[([^\]]*)\]/.exec(m[2])
    if (levels) keys[m[1]] = levels[1].split(",").map(function(s) { return s.trim() })
  }
  return keys
}

// keysym name -> character, from xkbcommon-keysyms.h.
function parseKeysyms(header) {
  var table = {}
  var re = /#define XKB_KEY_(\w+)\s+0x\w+\s+\/\*[ (]*U\+([0-9A-F]{4,6})/g
  var m
  while ((m = re.exec(header)) !== null) {
    if (!(m[1] in table)) table[m[1]] = String.fromCodePoint(parseInt(m[2], 16))
  }
  return table
}

function toChar(sym, keysyms) {
  if (!sym || sym === "NoSymbol") return ""
  if (/^U[0-9A-Fa-f]{4,6}$/.test(sym)) return String.fromCodePoint(parseInt(sym.slice(1), 16))
  if (sym in keysyms) return keysyms[sym]
  return sym.length === 1 ? sym : ""
}

// Combining Hebrew marks, which are drawn on a ◌.
function isMark(ch) {
  var c = ch ? ch.codePointAt(0) : 0
  return c >= 0x0591 && c <= 0x05c7 && "־׀׃׆".indexOf(ch) < 0
}

function markPosition(ch) {
  if (NIQQUD_ABOVE.indexOf(ch) >= 0) return "above"
  if (NIQQUD_INSIDE.indexOf(ch) >= 0) return "inside"
  return "below"
}

// Keycaps show letters in upper case, except where that changes the letter
// count (ß -> SS).
function keycapLabel(ch) {
  var upper = ch.toUpperCase()
  return upper.length === ch.length ? upper : ch
}

function level3Key(options) {
  var opts = String(options || "").split(",")
  for (var i = 0; i < opts.length; i++) {
    var o = opts[i].trim()
    if (o.indexOf("lv3:") === 0 && LEVEL3_KEYS[o.slice(4)]) return LEVEL3_KEYS[o.slice(4)]
  }
  return "altgr"
}

// key name -> what to show on that key, for every key the il layout defines.
// `labels` is parseSymbols() of the layout printed on the keycaps.
function characters(hebrew, labels, keysyms) {
  var out = {}
  for (var name in hebrew) {
    var syms = hebrew[name]
    var base = toChar(syms[0], keysyms)
    var shift = toChar(syms[1], keysyms)
    var altgr = toChar(syms[2], keysyms)
    out[name] = {
      base: base,
      // The Latin capital is implied by the label, so leave it out.
      shift: /^[A-Z]$/.test(shift) ? "" : shift,
      altgr: altgr,
      mark: isMark(altgr),
      markPosition: markPosition(altgr),
      label: keycapLabel(toChar((labels[name] || [])[0], keysyms)),
      letter: base >= "\u05d0" && base <= "\u05ea",
      baseName: NAMES[base] || "",
      altgrName: NAMES[altgr] || ""
    }
  }
  return out
}

// name -> #rrggbb from the theme's colors.toml.
function parseColors(toml) {
  var colors = {}
  var re = /^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/gm
  var m
  while ((m = re.exec(toml)) !== null) colors[m[1]] = m[2]
  return colors
}
