import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "superlig.futbol"

  component PlainTextIdle: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Commons.Color.foreground
    font.family: root.bar ? root.bar.fontFamily : ""
    font.pixelSize: Style.font.body
    property string glyph: ""
    text: glyph
  }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = pill;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  function refresh() {
    if (!todayProc.running) todayProc.running = true;
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle();
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey();
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close();
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
  }

  visible: true
  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Persisted onboarding state (favourites list), refreshed on file writes.
  property var favorites: []
  property string ntFavorite: ""

  FileView {
    id: stateFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/superlig.futbol/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseState(text())
  }

  function parseState(raw) {
    var parsed = Model.parseJson(String(raw || ""));
    var favs = (parsed && Array.isArray(parsed.favorites)) ? parsed.favorites : [];
    var ids = [];
    for (var i = 0; i < favs.length; i++) {
      var f = favs[i];
      ids.push(typeof f === "string" ? f : String((f && f.id) || f));
    }
    root.favorites = ids;
    root.ntFavorite = parsed && parsed.ntFavorite ? String(parsed.ntFavorite) : "";
  }

  // A favourite match today, live or already finished (club or national team).
  property var favoriteLive: null
  property double nowMs: Date.now()

  function matchScoreText(m) {
    if (!m) return "";
    if (m.homeScore < 0 || m.awayScore < 0) return "- : -";
    return m.homeScore + " : " + m.awayScore;
  }

  function minuteText(m) {
    if (!m) return "";
    if (m.finished) return "MS";
    var lv = m.liveData;
    if (lv && lv.substate === "halfTime") return "İY";
    if (m.live && lv && lv.periodStart > 0) {
      var base = lv.periodId === 2 ? 45 : 0;
      var min = Math.floor(Math.max(0, root.nowMs - lv.periodStart) / 60000) + base;
      return min + "'";
    }
    return "";
  }

  function updateFavoriteLive(feedMatches) {
    var today = Model.todayISO();
    var ntName = Model.ntMkName(root.ntFavorite);
    var clubBest = null, ntBest = null;
    for (var i = 0; i < feedMatches.length; i++) {
      var m = feedMatches[i];
      if (!m.live && !m.finished) continue;
      if (m.date !== today) continue;
      var isClubFav = root.favorites.indexOf(String(m.homeId)) !== -1 || root.favorites.indexOf(String(m.awayId)) !== -1;
      var isNtFav = root.ntFavorite !== "" && (m.home === ntName || m.away === ntName);
      if (isNtFav) {
        m.isNt = true;
        m.ntHomeCode = Model.ntCodeForMkName(m.home);
        m.ntAwayCode = Model.ntCodeForMkName(m.away);
      }
      if (isClubFav && (!clubBest || (m.live && !clubBest.live))) clubBest = m;
      if (isNtFav && (!ntBest || (m.live && !ntBest.live))) ntBest = m;
    }
    // Club wins when both exist; national team is the fallback.
    var pick = clubBest || ntBest;
    root.favoriteLive = pick;
    // Tight cadence while a favourite fixture is live; hourly otherwise.
    pollTimer.interval = (pick && pick.live) ? 45 * 1000 : root.refreshMinutes * 60 * 1000;
  }

  Timer {
    id: tick
    interval: 30000
    running: root.favoriteLive !== null
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  readonly property int refreshMinutes: Math.max(5, parseInt(root.settings.refreshMinutes, 10) || 10)

  Process {
    id: todayProc
    command: ["curl", "-fsS", "--max-time", "15",
      "https://www.mackolik.com/perform/p0/ajax/components/competition/livescores/json?sports[]=Soccer&matchDate=" + Model.todayISO()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(String(text || ""));
        var raw = parsed && parsed.data && parsed.data.matches;
        var list = [];
        if (raw) {
          for (var id in raw) {
            var m = raw[id];
            if (!m) continue;
            var score = m.score || {};
            var homeScore = parseInt(score.home, 10);
            var awayScore = parseInt(score.away, 10);
            list.push({
              homeId: String((m.homeTeam && m.homeTeam.id) || ""),
              awayId: String((m.awayTeam && m.awayTeam.id) || ""),
              home: Model.clean(m.homeTeam ? m.homeTeam.name : "", 40),
              away: Model.clean(m.awayTeam ? m.awayTeam.name : "", 40),
              homeCrest: (m.homeTeam && m.homeTeam.id) ? "https://file.mackolikfeeds.com/teams/" + m.homeTeam.id : "",
              awayCrest: (m.awayTeam && m.awayTeam.id) ? "https://file.mackolikfeeds.com/teams/" + m.awayTeam.id : "",
              homeScore: isNaN(homeScore) ? -1 : homeScore,
              awayScore: isNaN(awayScore) ? -1 : awayScore,
              date: String(m.date_time_utc || today()).slice(0, 10),
              live: m.state === "live",
              finished: m.state === "post",
              liveData: {
                substate: String(m.substate || "none"),
                periodId: parseInt(m.periodId, 10) || 0,
                periodStart: parseInt(m.periodStart, 10) || 0
              }
            });
          }
        }
        root.updateFavoriteLive(list);
      }
    }
  }

  // Helper so parseFinished's date fallback compiles before Model loads.
  function today() { return Model.todayISO(); }

  Timer {
    id: pollTimer
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  Rectangle {
    id: pill
    implicitWidth: pillRow.implicitWidth + Style.space(12)
    implicitHeight: Style.bar.statusSlot
    radius: Math.min(8, Style.cornerRadius)
    color: pillArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      // Idle state: the matchday ball.
      PlainTextIdle {
        id: idleBall
        visible: root.favoriteLive === null
        glyph: String.fromCodePoint(0xF1E3) // nf-fa-futbol_o
        anchors.verticalCenter: parent.verticalCenter
      }

      // Live/finished favourite fixture: badges + score + minute.
      Image {
        visible: root.favoriteLive !== null && status !== Image.Error
        anchors.verticalCenter: parent.verticalCenter
        source: root.favoriteLive
          ? (root.favoriteLive.isNt
              ? Qt.resolvedUrl("flags/" + root.favoriteLive.ntHomeCode + ".svg")
              : root.favoriteLive.homeCrest)
          : ""
        sourceSize: Qt.size(36, 24)
        width: Style.space(20)
        height: Style.space(14)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
      }
      PlainTextIdle {
        visible: root.favoriteLive !== null
        anchors.verticalCenter: parent.verticalCenter
        text: root.favoriteLive ? root.matchScoreText(root.favoriteLive) + (root.minuteText(root.favoriteLive) !== "" ? "  " + root.minuteText(root.favoriteLive) : "") : ""
        anchors.verticalCenterOffset: -1
      }
      Image {
        visible: root.favoriteLive !== null && status !== Image.Error
        anchors.verticalCenter: parent.verticalCenter
        source: root.favoriteLive
          ? (root.favoriteLive.isNt
              ? Qt.resolvedUrl("flags/" + root.favoriteLive.ntAwayCode + ".svg")
              : root.favoriteLive.awayCrest)
          : ""
        sourceSize: Qt.size(36, 24)
        width: Style.space(20)
        height: Style.space(14)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
      }
    }

    MouseArea {
      id: pillArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.togglePanel()
    }
  }

}
