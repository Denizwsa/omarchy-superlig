import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "superlig.futbol"
  ipcTarget: "superlig.futbol"
  manageIpc: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Inline plain-text component: fetched strings must never render as rich text.
  component PlainText: Text { textFormat: Text.PlainText }

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property bool openedFromHotkey: false

  readonly property color fg: root.bar && root.bar.foreground ? root.bar.foreground : Commons.Color.foreground
  readonly property color fgDim: Qt.darker(fg, 1.45)
  readonly property color fgFaint: Qt.darker(fg, 1.8)
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : ""
  readonly property string localeTag: String(Commons.I18n.formatLocale || "en-US").replace(/_/g, "-")
  readonly property string backendPath: decodeURIComponent(Qt.resolvedUrl("backend/mackolik.py").toString().replace(/^file:\/\//, ""))

  function open() {
    openedFromHotkey = false;
    root.controller.show();
    root.refreshAll();
  }
  function openFromHotkey() {
    openedFromHotkey = true;
    root.controller.show();
    root.refreshAll();
  }
  function close() {
    root.controller.hide();
  }
  function toggle() {
    if (root.opened) root.close();
    else root.openFromHotkey();
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction);
    return false;
  }

  // ---- State ---------------------------------------------------------------

  readonly property string ua: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  property var liveById: ({})
  property double nowMs: Date.now()
  property var selectedMatch: null
  readonly property bool detailOpen: selectedMatch !== null
  property var detail: ({})
  property bool detailLoading: false
  property string detailError: ""

  readonly property var leagues: Model.leagues
  property string leagueId: "482ofyysbdbeoxauk19yg7tdt" // Trendyol Süper Lig
  readonly property string leagueName: Model.leagueName(leagueId, leagueId)

  property int activeTab: 0 // 0 bugün · 1 yarın · 2 sonuçlar · 3 puan durumu
  property var standings: []
  property var matches: []
  property string season: ""
  property string errorText: ""
  property string lastUpdated: ""
  property double lastFullRefresh: 0

  readonly property var todayRows: Model.matchesOnDate(matches, Model.todayISO(), 40)
  readonly property var tomorrowRows: Model.matchesOnDate(matches, Model.tomorrowISO(), 40)
  readonly property var resultsRows: Model.playedDesc(matches, 12)
  readonly property var activeRows: activeTab === 0 ? todayRows : (activeTab === 1 ? tomorrowRows : resultsRows)

  readonly property bool loading: backendProc.running
  readonly property bool anyFetchRunning: backendProc.running
  readonly property int refreshMinutes: Math.max(5, parseInt(setting("refreshMinutes", 10), 10) || 10)

  readonly property var zoneColors: ({
    champions: "#35a854",
    europa: "#3d7bd9",
    conference: "#3d7bd9",
    promotion: "#3d7bd9",
    relegation: "#d94841"
  })

  function dateCaption(offsetDays) {
    var d = new Date();
    d.setDate(d.getDate() + offsetDays);
    try {
      return d.toLocaleDateString(root.localeTag, { day: "numeric", month: "long", year: "numeric", weekday: "long" });
    } catch (e) {
      return Qt.formatDateTime(d, "yyyy-MM-dd");
    }
  }

  // Live helpers: read root.nowMs so bindings tick with the 500ms timer.
  function liveMinuteText(lv) {
    if (!lv) return "";
    if (lv.substate === "halfTime") return "İY";
    if (lv.substate === "fullTime") return strings.t("match.ft");
    var base = lv.periodId === 2 ? 45 : 0;
    var min = base;
    if (lv.periodStart > 0) min = Math.floor(Math.max(0, root.nowMs - lv.periodStart) / 60000) + base;
    return min + "'";
  }

  function liveClockText(lv) {
    if (!lv) return "";
    if (lv.substate === "halfTime") return "İY";
    if (lv.substate === "fullTime") return strings.t("match.ft");
    var base = lv.periodId === 2 ? 45 : 0;
    var totalSec = lv.periodStart > 0 ? Math.max(0, Math.floor((root.nowMs - lv.periodStart) / 1000)) : 0;
    var min = Math.floor(totalSec / 60) + base;
    var sec = totalSec % 60;
    return min + ":" + (sec < 10 ? "0" : "") + sec;
  }

  function isLiveSelected() {
    var m = root.selectedMatch;
    if (!m) return false;
    var lv = root.liveById[m.id];
    return !!(lv && lv.state === "live");
  }

  function scoreFor(m) {
    if (!m) return null;
    var lv = m.id ? (root.liveById[m.id] || null) : null;
    if (lv && (lv.state === "live" || lv.state === "post") && lv.homeScore >= 0)
      return { homeScore: lv.homeScore, awayScore: lv.awayScore, htHome: lv.htHome, htAway: lv.htAway, state: lv.state, substate: lv.substate };
    if (m.status === "played" && m.homeScore >= 0)
      return { homeScore: m.homeScore, awayScore: m.awayScore, htHome: -1, htAway: -1, state: "post", substate: "fullTime" };
    return null;
  }

  function scoreText(m) {
    var s = root.scoreFor(m);
    return s ? s.homeScore + " : " + s.awayScore : "- : -";
  }

  function rowStatusText(m) {
    var lv = m.id ? (root.liveById[m.id] || null) : null;
    if (lv && lv.state === "live") return root.liveMinuteText(lv);
    if (lv && lv.state === "post") return strings.t("match.ft");
    return m.status === "played" ? strings.t("match.ft") : m.time;
  }

  function rowStatusColor(m) {
    var lv = m.id ? (root.liveById[m.id] || null) : null;
    if (lv && lv.state === "live") return "#e5484d";
    return m.status === "played" ? root.fgDim : root.accent;
  }

  function shortDate(iso) {
    var p = String(iso || "").split("-");
    if (p.length !== 3) return "";
    var d = new Date(+p[0], (+p[1]) - 1, +p[2]);
    try {
      return d.toLocaleDateString(root.localeTag, { day: "numeric", month: "short" });
    } catch (e) {
      return iso;
    }
  }

  // ---- Network (backend does the heavy lifting) ------------------------------

  function refreshAll(force) {
    var now = Date.now();
    if (!force && now - lastFullRefresh < 60 * 1000 && lastFullRefresh > 0) return;
    lastFullRefresh = now;
    if (!backendProc.running) backendProc.running = true;
    if (!dailyProc.running) dailyProc.running = true;
  }

  function openMatch(m) {
    if (!m || !m.id) return;
    selectedMatch = m;
    detail = ({});
    detailError = "";
    detailLoading = true;
    if (!detailProc.running) {
      detailProc.command = ["/usr/bin/python3", root.backendPath, "match", m.id];
      detailProc.running = true;
    }
  }

  function closeDetail() {
    selectedMatch = null;
    detail = ({});
    detailError = "";
    detailLoading = false;
  }

  function selectLeague(id) {
    if (id === leagueId) return;
    leagueId = id;
    standings = [];
    matches = [];
    season = "";
    errorText = "";
    lastFullRefresh = 0;
    root.closeDetail();
    refreshAll(true);
  }

  function selectTab(index) {
    if (index === activeTab) return;
    activeTab = index;
    root.closeDetail();
  }

  Process {
    id: backendProc
    command: ["/usr/bin/python3", root.backendPath, "all", root.leagueId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed) { root.errorText = strings.t("state.error"); return; }
        if (parsed.error) { root.errorText = strings.t("state.error"); return; }

        var mOut = [];
        var rawMatches = Array.isArray(parsed.matches) ? parsed.matches : [];
        for (var i = 0; i < rawMatches.length && mOut.length < 40 * 40; i++) {
          var m = rawMatches[i];
          if (!m) continue;
          var date = String(m.date || "");
          if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
          mOut.push({
            id: Model.clean(m.id, 64),
            date: date,
            time: /^\d{2}:\d{2}$/.test(String(m.time || "")) ? String(m.time) : "",
            status: m.status === "played" ? "played" : "fixture",
            home: Model.clean(m.home, 60),
            away: Model.clean(m.away, 60),
            homeCrest: Model.safeUrl(m.homeCrest),
            awayCrest: Model.safeUrl(m.awayCrest),
            homeScore: Math.max(-1, parseInt(m.homeScore, 10) || -1),
            awayScore: Math.max(-1, parseInt(m.awayScore, 10) || -1)
          });
        }

        var sOut = [];
        var rawTable = Array.isArray(parsed.standings) ? parsed.standings : [];
        for (var j = 0; j < rawTable.length && sOut.length < 40; j++) {
          var r = rawTable[j];
          if (!r) continue;
          sOut.push({
            rank: parseInt(r.rank, 10) || 0,
            teamId: Model.clean(r.teamId, 40),
            team: Model.clean(r.team, 60),
            crest: Model.safeUrl(r.crest),
            played: parseInt(r.played, 10) || 0,
            win: parseInt(r.win, 10) || 0,
            draw: parseInt(r.draw, 10) || 0,
            loss: parseInt(r.loss, 10) || 0,
            gf: parseInt(r.gf, 10) || 0,
            ga: parseInt(r.ga, 10) || 0,
            gd: parseInt(r.gd, 10) || 0,
            pts: parseInt(r.pts, 10) || 0,
            zone: Model.clean(r.zone, 16),
            form: Model.clean(r.form, 8)
          });
        }

        root.matches = mOut;
        root.standings = sOut;
        root.season = Model.clean(parsed.season, 16);
        root.errorText = "";
        root.lastUpdated = Model.nowTime();
      }
    }
  }

  // Daily livescores feed: state (pre/live/post) + periodStart per match uuid.
  // Failures are silent — the list just shows times/scores from the fixtures page.
  Process {
    id: dailyProc
    command: ["curl", "-fsS", "--max-time", "20", "-A", root.ua,
      "https://www.mackolik.com/perform/p0/ajax/components/competition/livescores/json?sports[]=Soccer&matchDate=" + Model.todayISO()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(String(text || ""));
        var live = Model.parseLiveFeed(parsed);
        if (live && Object.keys(live).length > 0) root.liveById = live;
      }
    }
  }

  Process {
    id: detailProc
    command: ["/usr/bin/python3", root.backendPath, "match", "0000000000000000000000000"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.detailLoading = false;
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed || parsed.error) { root.detailError = strings.t("state.error"); return; }

        var evOut = [];
        var rawEvents = Array.isArray(parsed.events) ? parsed.events : [];
        for (var i = 0; i < rawEvents.length && evOut.length < 60; i++) {
          var e = rawEvents[i];
          if (!e) continue;
          var side = e.side === "home" ? "home" : (e.side === "away" ? "away" : "");
          evOut.push({
            type: Model.clean(e.type, 12),
            subType: Model.clean(e.subType, 8),
            side: side,
            minute: Math.max(0, parseInt(e.minute, 10) || 0),
            player: Model.clean(e.player, 60),
            playerOut: Model.clean(e.playerOut, 60),
            assist: Model.clean(e.assist, 60),
            score: Model.clean(e.score, 8)
          });
        }

        function xiOut(raw) {
          var items = [];
          var list = Array.isArray(raw) ? raw : [];
          for (var j = 0; j < list.length && items.length < 11; j++) {
            var p = list[j];
            if (!p) continue;
            items.push({ num: Model.clean(p.num, 3), name: Model.clean(p.name, 60) });
          }
          return items;
        }

        var officials = [];
        var rawOff = Array.isArray(parsed.officials) ? parsed.officials : [];
        for (var k = 0; k < rawOff.length && officials.length < 4; k++)
          officials.push(Model.clean(rawOff[k], 60));

        root.detail = {
          events: evOut,
          homeXi: xiOut(parsed.homeXi),
          awayXi: xiOut(parsed.awayXi),
          homeFormation: Model.clean(parsed.homeFormation, 16),
          awayFormation: Model.clean(parsed.awayFormation, 16),
          officials: officials
        };
      }
    }
  }

  // 500ms ticker for live minute/second displays; also keeps list minutes fresh.
  Timer {
    id: nowTicker
    interval: 500
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  // Auto-refresh only while the panel is open; failures keep last-good data.
  Timer {
    interval: root.refreshMinutes * 60 * 1000
    running: root.opened
    repeat: true
    onTriggered: root.refreshAll(true)
  }

  // ---- Panel shell ---------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(880))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: panelColumn.implicitHeight
      anchors.fill: parent
      blocked: false
      onReturnRequested: root.refreshAll(true)
      onCloseRequested: { if (root.detailOpen) root.closeDetail(); else root.close(); }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dy * 46));
      }
      onTextKey: function(t, modifiers) {
        if (t === "r") root.refreshAll(true);
        else if (t === "b") { if (root.detailOpen) root.closeDetail(); }
        else if (t === "1") root.selectTab(0);
        else if (t === "2") root.selectTab(1);
        else if (t === "3") root.selectTab(2);
        else if (t === "4") root.selectTab(3);
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: panelColumn
          width: flick.width
          spacing: Style.space(12)

          // ===== Header
          Item {
            width: parent.width
            height: headerColumn.implicitHeight + Style.space(6)

            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(12)

              PlainText {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xF1E3)
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
              Column {
                id: headerColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                PlainText {
                  text: root.leagueName
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  font.letterSpacing: 0.5
                }
                PlainText {
                  visible: root.season !== ""
                  text: strings.t("table.season").arg(root.season)
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.5
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(30)
                height: Style.space(30)
                radius: Math.min(6, Style.cornerRadius)
                color: refreshArea.containsMouse ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
                PlainText {
                  anchors.centerIn: parent
                  text: String.fromCodePoint(0xF050F) // nf-md-refresh
                  color: refreshArea.containsMouse ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
                MouseArea {
                  id: refreshArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.refreshAll(true)
                }
              }

              Rectangle {
                width: Style.space(30)
                height: Style.space(30)
                radius: Math.min(6, Style.cornerRadius)
                color: closeArea.containsMouse ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
                PlainText {
                  anchors.centerIn: parent
                  text: "✕"
                  color: closeArea.containsMouse ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
                MouseArea {
                  id: closeArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.close()
                }
              }
            }
          }

          // ===== League chips
          Flickable {
            id: chipsFlick
            width: parent.width
            height: Style.space(36)
            contentWidth: chipsRow.implicitWidth + Style.space(32)
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
              id: chipsRow
              x: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Repeater {
                model: root.leagues

                Rectangle {
                  required property var modelData
                  readonly property bool selected: modelData.id === root.leagueId
                  height: Style.space(28)
                  width: chipText.implicitWidth + Style.space(22)
                  radius: height / 2
                  color: selected ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
                  border.width: selected ? 0 : 1
                  border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)

                  PlainText {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData.short
                    color: selected ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: selected
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectLeague(modelData.id)
                  }
                }
              }
            }
          }

          // ===== Tabs: Bugün · Yarın · Sonuçlar · Puan Durumu
          Row {
            x: Style.space(16)
            width: parent.width - Style.space(32)
            height: Style.space(38)
            spacing: Style.space(4)

            Repeater {
              model: [
                { label: strings.t("tab.today") },
                { label: strings.t("tab.tomorrow") },
                { label: strings.t("tab.results") },
                { label: strings.t("tab.table") }
              ]

              Item {
                required property var modelData
                required property int index
                readonly property bool selected: index === root.activeTab
                width: (panelColumn.width - Style.space(32) - Style.space(12)) / 4
                height: parent.height

                Column {
                  anchors.fill: parent
                  spacing: Style.space(4)

                  PlainText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    color: selected ? root.fg : root.fgDim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: selected
                  }
                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.7
                    height: 2
                    radius: 1
                    color: selected ? root.accent : "transparent"
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectTab(index)
                }
              }
            }
          }

          // ===== Error banner: last-good data stays on screen
          Rectangle {
            visible: root.errorText !== ""
            width: parent.width - Style.space(32)
            x: Style.space(16)
            height: Style.space(30)
            radius: Math.min(6, Style.cornerRadius)
            color: Qt.rgba(0.9, 0.63, 0.24, 0.14)
            border.width: 1
            border.color: Qt.rgba(0.9, 0.63, 0.24, 0.35)

            Row {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              spacing: Style.space(8)
              PlainText {
                text: String.fromCodePoint(0xF0176) // nf-md-alert
                color: "#e5a13d"
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              PlainText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.errorText
                color: "#e5a13d"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          // ===== Match detail (single fixture, opened by pressing a row)
          Item {
            visible: root.detailOpen
            width: parent.width
            implicitHeight: root.detailOpen ? detailContent.implicitHeight : 0

            Column {
              id: detailContent
              width: parent.width
              spacing: Style.space(4)

              // Back + date row
              Item {
                width: parent.width
                height: Style.space(32)

                PlainText {
                  id: backText
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("detail.back")
                  color: backArea.containsMouse ? root.accent : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                MouseArea {
                  id: backArea
                  anchors.fill: backText
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.closeDetail()
                }
                PlainText {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.selectedMatch ? (root.shortDate(root.selectedMatch.date) + (root.selectedMatch.time ? "  ·  " + root.selectedMatch.time : "")) : ""
                  color: root.fgFaint
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              // Loading / error line
              Item {
                visible: root.detailLoading || root.detailError !== ""
                width: parent.width
                height: Style.space(detailError !== "" ? 30 : 60)
                PlainText {
                  anchors.centerIn: parent
                  text: root.detailError !== "" ? root.detailError : strings.t("state.loading")
                  color: root.detailError !== "" ? "#e5a13d" : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.italic: true
                }
              }

              // Score hero
              Item {
                width: parent.width
                height: Style.space(124)

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(18)

                  Column {
                    width: Style.space(240)
                    spacing: Style.space(8)
                    Image {
                      anchors.horizontalCenter: parent.horizontalCenter
                      visible: !!(root.selectedMatch && root.selectedMatch.homeCrest !== "") && status !== Image.Error
                      source: root.selectedMatch ? root.selectedMatch.homeCrest : ""
                      sourceSize: Qt.size(112, 112)
                      width: Style.space(56)
                      height: Style.space(56)
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: true
                    }
                    PlainText {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      text: root.selectedMatch ? root.selectedMatch.home : ""
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: true
                    }
                  }

                  Column {
                    width: Style.space(160)
                    spacing: Style.space(4)
                    PlainText {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: root.selectedMatch
                        ? (root.scoreFor(root.selectedMatch) ? root.scoreText(root.selectedMatch) : (root.selectedMatch.time || "- : -"))
                        : "- : -"
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.displayLarge * 1.6
                      font.bold: true
                    }
                    PlainText {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: {
                        var m = root.selectedMatch;
                        if (!m) return "";
                        var lv = m.id ? (root.liveById[m.id] || null) : null;
                        if (lv && lv.state === "live")
                          return strings.t("match.live") + "  ·  " + root.liveClockText(lv);
                        if (lv && lv.state === "post") return strings.t("match.ft");
                        if (m.status === "played") return strings.t("match.ft");
                        return "";
                      }
                      color: {
                        var m = root.selectedMatch;
                        var lv = m && m.id ? (root.liveById[m.id] || null) : null;
                        return lv && lv.state === "live" ? "#e5484d" : root.fgDim;
                      }
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    // Half-time score when the live feed reports it
                    PlainText {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      visible: {
                        var lv = root.selectedMatch && root.selectedMatch.id ? (root.liveById[root.selectedMatch.id] || null) : null;
                        return !!(lv && lv.htHome >= 0 && lv.htAway >= 0 && lv.state !== "pre");
                      }
                      text: {
                        var lv = root.selectedMatch && root.selectedMatch.id ? (root.liveById[root.selectedMatch.id] || null) : null;
                        return lv ? ("İY " + lv.htHome + "-" + lv.htAway) : "";
                      }
                      color: root.fgFaint
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Column {
                    width: Style.space(240)
                    spacing: Style.space(8)
                    Image {
                      anchors.horizontalCenter: parent.horizontalCenter
                      visible: !!(root.selectedMatch && root.selectedMatch.awayCrest !== "") && status !== Image.Error
                      source: root.selectedMatch ? root.selectedMatch.awayCrest : ""
                      sourceSize: Qt.size(112, 112)
                      width: Style.space(56)
                      height: Style.space(56)
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: true
                    }
                    PlainText {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      text: root.selectedMatch ? root.selectedMatch.away : ""
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: true
                    }
                  }
                }
              }

              // Officials
              PlainText {
                visible: root.detail.officials !== undefined && root.detail.officials.length > 0
                leftPadding: Style.space(16)
                text: strings.t("detail.officials") + ":  " + (root.detail.officials || []).join("  ·  ")
                color: root.fgDim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10) }

              // Events header
              PlainText {
                leftPadding: Style.space(16)
                text: strings.t("detail.events").toUpperCase()
                color: root.fgFaint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.5
                font.bold: true
              }

              Item {
                visible: !!(!root.detailLoading && root.detailError === ""
                  && (!root.detail.events || root.detail.events.length === 0)
                  && root.selectedMatch && root.selectedMatch.status === "fixture")
                width: parent.width
                height: Style.space(60)
                PlainText {
                  anchors.centerIn: parent
                  text: strings.t("detail.notPlayed")
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.italic: true
                }
              }

              Repeater {
                model: root.detail.events || []

                Item {
                  required property var modelData
                  required property int index
                  readonly property bool awaySide: modelData.side === "away"
                  width: parent.width
                  height: evRow.implicitHeight + Style.space(8)

                  Rectangle {
                    anchors.fill: parent
                    color: index % 2 === 0 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03) : "transparent"
                  }

                  Row {
                    id: evRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(16)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(16)
                    spacing: Style.space(10)
                    layoutDirection: awaySide ? Qt.RightToLeft : Qt.LeftToRight

                    Rectangle {
                      width: Style.space(38)
                      height: Style.space(22)
                      radius: 11
                      anchors.verticalCenter: parent.verticalCenter
                      color: modelData.type === "goal" ? "#35a854"
                           : modelData.type === "substitute" ? "#5b6b7a"
                           : (modelData.subType === "rc" ? "#d94841" : "#e5c158")
                      PlainText {
                        anchors.centerIn: parent
                        text: modelData.minute + "'"
                        color: modelData.type === "card" && modelData.subType !== "rc" ? "#332a00" : "#ffffff"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Column {
                      width: parent.width - Style.space(50)
                      spacing: 1

                      PlainText {
                        width: parent.width
                        horizontalAlignment: awaySide ? Text.AlignRight : Text.AlignLeft
                        elide: Text.ElideRight
                        text: modelData.type === "substitute"
                          ? strings.t("ev.subIn").arg(modelData.player)
                          : modelData.player + (modelData.type === "goal" && modelData.score !== "" ? "  ·  " + modelData.score : "")
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.type === "goal"
                      }
                      PlainText {
                        visible: modelData.assist !== "" || modelData.playerOut !== "" || modelData.type === "card"
                        width: parent.width
                        horizontalAlignment: awaySide ? Text.AlignRight : Text.AlignLeft
                        elide: Text.ElideRight
                        text: modelData.type === "goal" && modelData.assist !== ""
                          ? strings.t("ev.assist").arg(modelData.assist)
                          : modelData.type === "substitute"
                            ? strings.t("ev.subOut").arg(modelData.playerOut)
                            : (modelData.subType === "rc" ? strings.t("ev.rc") : strings.t("ev.yc"))
                        color: root.fgDim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }
              }

              // Lineups
              Column {
                visible: !!((root.detail.homeXi && root.detail.homeXi.length > 0) || (root.detail.awayXi && root.detail.awayXi.length > 0))
                width: parent.width
                spacing: Style.space(4)

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10) }

                PlainText {
                  leftPadding: Style.space(16)
                  topPadding: Style.space(4)
                  text: strings.t("detail.firstxi").toUpperCase()
                  color: root.fgFaint
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.5
                  font.bold: true
                }

                Row {
                  x: Style.space(16)
                  width: parent.width - Style.space(32)
                  spacing: Style.space(14)

                  Repeater {
                    model: [
                      { side: "home", name: root.selectedMatch ? root.selectedMatch.home : "",
                        formation: root.detail.homeFormation || "", xi: root.detail.homeXi || [],
                        crest: root.selectedMatch ? root.selectedMatch.homeCrest : "" },
                      { side: "away", name: root.selectedMatch ? root.selectedMatch.away : "",
                        formation: root.detail.awayFormation || "", xi: root.detail.awayXi || [],
                        crest: root.selectedMatch ? root.selectedMatch.awayCrest : "" }
                    ]

                    Column {
                      required property var modelData
                      width: (parent.width - Style.space(14)) / 2
                      spacing: Style.space(8)

                      Row {
                        spacing: Style.space(8)
                        Image {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(22)
                          height: Style.space(22)
                          source: modelData.crest
                          sourceSize: Qt.size(44, 44)
                          fillMode: Image.PreserveAspectFit
                          visible: modelData.crest !== "" && status !== Image.Error
                          asynchronous: true
                          cache: true
                        }
                        PlainText {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(150)
                          elide: Text.ElideRight
                          text: modelData.name
                          color: root.fg
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }
                        Rectangle {
                          visible: modelData.formation !== ""
                          anchors.verticalCenter: parent.verticalCenter
                          width: formationText.implicitWidth + Style.space(14)
                          height: Style.space(20)
                          radius: 10
                          color: "transparent"
                          border.width: 1
                          border.color: root.accent
                          PlainText {
                            id: formationText
                            anchors.centerIn: parent
                            text: modelData.formation
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }
                      }

                      Repeater {
                        model: modelData.xi
                        Row {
                          required property var modelData
                          width: parent.width
                          spacing: Style.space(10)
                          PlainText {
                            width: Style.space(28)
                            horizontalAlignment: Text.AlignRight
                            text: modelData.num
                            color: root.fgFaint
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                          }
                          PlainText {
                            width: parent.width - Style.space(38)
                            elide: Text.ElideRight
                            text: modelData.name
                            color: root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                          }
                        }
                      }
                    }
                  }
                }
              }

              Item { width: 1; height: Style.space(6) }
            }
          }

          // ===== Matches list (tabs 0-2)
          Item {
            width: parent.width
            visible: !root.detailOpen && root.activeTab !== 3
            implicitHeight: (!root.detailOpen && root.activeTab !== 3) ? matchesContent.implicitHeight : 0

            Column {
              id: matchesContent
              width: parent.width
              spacing: Style.space(4)

              PlainText {
                leftPadding: Style.space(16)
                text: root.activeTab === 0 ? root.dateCaption(0)
                    : root.activeTab === 1 ? root.dateCaption(1)
                    : strings.t("tab.results")
                color: root.fgFaint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
              }

              Item {
                visible: root.activeRows.length === 0
                width: parent.width
                height: Style.space(90)
                PlainText {
                  anchors.centerIn: parent
                  text: root.anyFetchRunning
                    ? strings.t("state.loading")
                    : (root.activeTab === 0 ? strings.t("state.emptyToday")
                       : root.activeTab === 1 ? strings.t("state.emptyTomorrow")
                       : strings.t("state.emptyResults"))
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.italic: true
                }
              }

              Repeater {
                model: root.activeRows

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: Style.space(48)
                  color: rowArea.containsMouse
                    ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    : index % 2 === 0 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03) : "transparent"

                  MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMatch(modelData)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(16)
                    anchors.rightMargin: Style.space(16)
                    spacing: Style.space(10)
                    LayoutMirroring.enabled: false

                    // Time / MS + date caption on the results tab
                    Column {
                      width: Style.space(56)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1

                      PlainText {
                        text: root.rowStatusText(modelData)
                        color: root.rowStatusColor(modelData)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: modelData.status !== "played" || root.rowStatusColor(modelData) === "#e5484d"
                      }
                      PlainText {
                        visible: root.activeTab === 2
                        text: root.shortDate(modelData.date)
                        color: root.fgFaint
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    // Home
                    Row {
                      width: Style.space(255)
                      anchors.verticalCenter: parent.verticalCenter
                      layoutDirection: Qt.RightToLeft
                      spacing: Style.space(8)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.homeCrest !== "" && status !== Image.Error
                        source: modelData.homeCrest
                        sourceSize: Qt.size(44, 44)
                        width: Style.space(22)
                        height: Style.space(22)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        LayoutMirroring.enabled: false
                      }
                      PlainText {
                        width: Style.space(221)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: modelData.home
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                    }

                    // Score
                    PlainText {
                      width: Style.space(84)
                      anchors.verticalCenter: parent.verticalCenter
                      horizontalAlignment: Text.AlignHCenter
                      text: root.scoreText(modelData)
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: root.scoreFor(modelData) !== null
                    }

                    // Away
                    Row {
                      width: Style.space(255)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(8)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.awayCrest !== "" && status !== Image.Error
                        source: modelData.awayCrest
                        sourceSize: Qt.size(44, 44)
                        width: Style.space(22)
                        height: Style.space(22)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                      }
                      PlainText {
                        width: Style.space(221)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: modelData.away
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                    }
                  }
                }
              }
            }
          }

          // ===== Standings table (tab 3)
          Item {
            visible: !root.detailOpen && root.activeTab === 3
            width: parent.width
            implicitHeight: (!root.detailOpen && root.activeTab === 3) ? tableContent.implicitHeight : 0

            Column {
              id: tableContent
              width: parent.width
              spacing: 0

              Item {
                visible: root.standings.length === 0
                width: parent.width
                height: Style.space(120)
                PlainText {
                  anchors.centerIn: parent
                  text: root.anyFetchRunning ? strings.t("state.loading") : strings.t("state.emptyTable")
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.italic: true
                }
              }

              // Header row
              Row {
                x: Style.space(16)
                width: parent.width - Style.space(32)
                height: Style.space(30)

                PlainText { width: Style.space(30); text: "#"; color: root.fgFaint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                PlainText { width: Style.space(28); text: "" }
                PlainText { width: Style.space(210); text: strings.t("col.team").toUpperCase(); color: root.fgFaint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                  model: [
                    strings.t("col.played"), strings.t("col.won"), strings.t("col.drawn"), strings.t("col.lost"),
                    strings.t("col.gf"), strings.t("col.ga"), strings.t("col.gd")
                  ]
                  PlainText {
                    required property var modelData
                    width: Style.space(44)
                    text: modelData
                    color: root.fgFaint
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                PlainText { width: Style.space(50); text: strings.t("col.pts"); color: root.fgFaint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                PlainText { width: Style.space(110); text: strings.t("col.form"); color: root.fgFaint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
              }

              Rectangle { width: parent.width - Style.space(32); x: Style.space(16); height: 1; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) }

              Repeater {
                model: root.standings

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: Style.space(36)
                  color: index % 2 === 0 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03) : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(16)
                    anchors.rightMargin: Style.space(16)

                    // Rank, zone-tinted
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: modelData.zone !== "" ? Qt.rgba(
                        parseInt(root.zoneColors[modelData.zone].substr(1, 2), 16) / 255,
                        parseInt(root.zoneColors[modelData.zone].substr(3, 2), 16) / 255,
                        parseInt(root.zoneColors[modelData.zone].substr(5, 2), 16) / 255,
                        0.75) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                      PlainText {
                        anchors.centerIn: parent
                        text: modelData.rank
                        color: modelData.zone !== "" ? "#ffffff" : root.fgDim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }
                    }
                    Item { width: Style.space(8); height: 1 }
                    Image {
                      width: Style.space(20)
                      height: Style.space(20)
                      anchors.verticalCenter: parent.verticalCenter
                      source: modelData.crest
                      sourceSize: Qt.size(40, 40)
                      fillMode: Image.PreserveAspectFit
                      visible: modelData.crest !== "" && status !== Image.Error
                      asynchronous: true
                      cache: true
                    }
                    PlainText {
                      width: Style.space(210)
                      anchors.verticalCenter: parent.verticalCenter
                      leftPadding: Style.space(6)
                      elide: Text.ElideRight
                      text: modelData.team
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: modelData.rank === 1
                    }
                    Repeater {
                      model: [modelData.played, modelData.win, modelData.draw, modelData.loss, modelData.gf, modelData.ga]
                      PlainText {
                        required property var modelData
                        width: Style.space(44)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: root.fgDim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        horizontalAlignment: Text.AlignHCenter
                      }
                    }
                    PlainText {
                      width: Style.space(44)
                      anchors.verticalCenter: parent.verticalCenter
                      text: (modelData.gd > 0 ? "+" : "") + modelData.gd
                      color: root.fgDim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      horizontalAlignment: Text.AlignHCenter
                    }
                    PlainText {
                      width: Style.space(50)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.pts
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                    }
                    // Form pills, oldest → newest
                    Row {
                      width: Style.space(110)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 3

                      Repeater {
                        model: modelData.form.split("").slice(0, 5)
                        Rectangle {
                          required property var modelData
                          width: Style.space(16)
                          height: Style.space(16)
                          radius: 8
                          color: modelData === "W" ? "#35a854" : modelData === "L" ? "#d94841" : "#8b8b8b"
                          PlainText {
                            anchors.centerIn: parent
                            text: modelData
                            color: "#ffffff"
                            font.family: root.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Zone legend
              Row {
                visible: root.standings.length > 0
                x: Style.space(16)
                width: parent.width - Style.space(32)
                height: Style.space(34)
                spacing: Style.space(14)

                Repeater {
                  model: [
                    { color: root.zoneColors.champions, label: strings.t("legend.champions") },
                    { color: root.zoneColors.europa, label: strings.t("legend.europe") },
                    { color: root.zoneColors.relegation, label: strings.t("legend.relegation") }
                  ]
                  Row {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(5)
                    Rectangle { width: 8; height: 8; radius: 4; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                    PlainText { text: modelData.label; color: root.fgDim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                  }
                }
              }
            }
          }

          // ===== Footer
          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10)
          }
          Item {
            width: parent.width
            height: Style.space(22)

            PlainText {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              text: strings.t("foot.source")
              color: root.fgFaint
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            PlainText {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              visible: root.lastUpdated !== ""
              text: strings.t("foot.updated").arg(root.lastUpdated)
              color: root.fgFaint
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Item { width: 1; height: Style.space(6) }
        }
      }
    }
  }

  ShellIpc {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refreshAll(true) }
  }
}
