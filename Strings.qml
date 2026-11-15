import QtQuick
import Quickshell.Io

// Plugin-local strings: like Commons.Translations, but the language is
// chosen by the plugin itself (onboarding screen), not by the system.
// Falls back to en.json when a key is missing in the chosen catalog.
QtObject {
  id: root

  property string language: "en"
  property string directory: ""

  readonly property string baseLanguage: language.split("-")[0]
  readonly property string directoryPath: String(directory).replace(/^file:\/\//, "").replace(/\/+$/, "")

  readonly property var englishStrings: parseCatalog(englishFile.text())
  readonly property var baseStrings: parseCatalog(baseFile.text())
  readonly property var languageStrings: parseCatalog(languageFile.text())

  readonly property var strings: {
    var merged = ({})
    var layers = [root.englishStrings, root.baseStrings, root.languageStrings]
    for (var i = 0; i < layers.length; i++) {
      var layer = layers[i]
      for (var key in layer) {
        var value = layer[key]
        if (typeof value === "string" || (value && typeof value === "object")) merged[key] = value
      }
    }
    return merged
  }

  property FileView englishFile: FileView {
    path: root.directoryPath + "/en.json"
    watchChanges: false
    printErrors: false
    onLoaded: function() { root.englishStrings; }
  }
  property FileView baseFile: FileView {
    path: root.directoryPath + "/" + root.baseLanguage + ".json"
    watchChanges: false
    printErrors: false
    onLoaded: function() { root.baseStrings; }
  }
  property FileView languageFile: FileView {
    path: root.directoryPath + "/" + root.language + ".json"
    watchChanges: false
    printErrors: false
    onLoaded: function() { root.languageStrings; }
  }

  function parseCatalog(text) {
    var raw = String(text || "").trim()
    if (!raw) return ({})
    try { return JSON.parse(raw) } catch (e) { return ({}) }
  }

  function t(key, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") value = value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  function tn(key, count, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") {
      var form = (count === 1 && value.one) ? value.one : value.other
      if (form) return String(form).replace("%1", count)
    }
    return t(key, fallback)
  }
}
