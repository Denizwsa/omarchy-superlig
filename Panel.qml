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

  Strings { id: strings; directory: Qt.resolvedUrl("i18n"); language: root.languageCode }

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

  // ---- Onboarding / favourites ---------------------------------------------
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/superlig.futbol"
  readonly property string statePath: stateDir + "/state.json"
  readonly property string cachePath: stateDir + "/teams.json"

  property string languageCode: "en"
  property bool onboarded: false
  property var favorites: []
  property var favoriteNames: []
  property string ntFavorite: ""
  property var teamLeagueMap: ({}) // teamId -> leagueId
  property string wizardQuery: ""
  property string wizardTeamSearch: ""
  property var wizardResults: []
  property bool wizardSearching: false
  property int wizardStep: 0

  readonly property var sortedLeagues: {
    var out = Model.sortLeagues(root.leagues, root.favorites, root.languageCode)
    // Promote leagues containing a favourite team when we have the map.
    if (root.favorites.length === 0 || Object.keys(root.teamLeagueMap).length === 0) return out
    var counts = {}
    for (var i = 0; i < root.favorites.length; i++) {
      var lg = root.teamLeagueMap[root.favorites[i]]
      if (lg) counts[lg] = (counts[lg] || 0) + 1
    }
    out = out.slice()
    out.sort(function(a, b) {
      var ca = counts[a.id] || 0, cb = counts[b.id] || 0
      if (ca !== cb) return cb - ca
      return 0
    })
    return out
  }

  function saveState() {
    // Atomic-ish write via a temp file + rename.
    var favObjects = [];
    for (var i = 0; i < root.favorites.length; i++) {
      favObjects.push({ id: root.favorites[i], name: root.favoriteNames[i] || root.favorites[i] });
    }
    var payload = JSON.stringify({
      onboarded: true,
      language: root.languageCode,
      favorites: favObjects,
      ntFavorite: root.ntFavorite
    })
    writeStateProc.command = ["/usr/bin/python3", "-c",
      "import json, os, sys\n" +
      "p = sys.argv[1]\n" +
      "d = os.path.dirname(p)\n" +
      "os.makedirs(d, exist_ok=True)\n" +
      "tmp = p + '.tmp'\n" +
      "open(tmp, 'w', encoding='utf-8').write(sys.argv[2])\n" +
      "os.replace(tmp, p)\n",
      root.statePath, payload]
    writeStateProc.running = true
  }

  function loadStateFromDisk() {
    stateFile.reload()
  }

  function finishOnboarding() {
    root.onboarded = true
    saveState()
    // Kick off a background fetch of all standings to build the team→league map.
    fetchAllStandings()
  }

  // Background: fetch every league's table, cache teamId→leagueId map.
  property var pendingLeagueFetches: []

  function fetchAllStandings() {
    pendingLeagueFetches = Model.leagues.map(function(l) { return l.id })
    if (!allStandingsProc.running) allStandingsProc.running = true
  }

  function applyLanguage(code) {
    if (code === root.languageCode) return
    root.languageCode = code
  }

  function toggleFavorite(teamId) {
    var idList = root.favorites.slice()
    var nameList = root.favoriteNames.slice()
    var idx = idList.indexOf(teamId)
    if (idx === -1) {
      var name = teamId;
      for (var i = 0; i < root.wizardResults.length; i++) {
        if (root.wizardResults[i].id === teamId) { name = root.wizardResults[i].name; break; }
      }
      idList.push(teamId);
      nameList.push(name);
    } else {
      idList.splice(idx, 1);
      nameList.splice(idx, 1);
    }
    root.favorites = idList;
    root.favoriteNames = nameList;
  }

  readonly property var leagues: Model.leagues
  property string leagueId: "482ofyysbdbeoxauk19yg7tdt" // Trendyol Süper Lig
  readonly property bool ntMode: leagueId.indexOf("nt:") === 0
  readonly property string ntCode: ntMode ? leagueId.slice(3) : ""
  readonly property string leagueName: ntMode
    ? Model.ntMkName(ntCode) + (Model.ntIsUefa(ntCode) ? " — UEFA Uluslar Ligi" : "")
    : Model.leagueName(leagueId, leagueId)

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
    if (root.ntMode) {
      if (!ntProc.running) ntProc.running = true;
    } else if (!backendProc.running) {
      backendProc.command = ["/usr/bin/python3", root.backendPath, "all", leagueId];
      backendProc.running = true;
    }
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
    if (ntFavorite !== "" && !ntProc.running) ntProc.command = ["/usr/bin/python3", root.backendPath, "all", "595nsvo7ykvoe690b1e4u5n56"];
    root.closeDetail();
    refreshAll(true);
  }

  function selectTab(index) {
    if (index === activeTab) return;
    activeTab = index;
    root.closeDetail();
    if (index === 4) root.refreshNews();
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

  // ---- State persistence (FileView watcher + atomic writer) ---------------

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseState(text())
  }

  function parseState(raw) {
    var parsed = Model.parseJson(String(raw || ""));
    if (!parsed) { root.onboarded = false; return; }
    root.languageCode = Model.clean(parsed.language, 10) || "en";
    var favs = Array.isArray(parsed.favorites) ? parsed.favorites : [];
    var ids = [], names = [];
    for (var i = 0; i < favs.length; i++) {
      var f = favs[i];
      if (typeof f === "string") { ids.push(f); names.push(f); }
      else if (f && f.id) { ids.push(String(f.id)); names.push(String(f.name || f.id)); }
    }
    root.favorites = ids;
    root.favoriteNames = names;
    root.ntFavorite = Model.clean(parsed.ntFavorite, 12);
    root.onboarded = parsed.onboarded === true;
  }

  Process {
    id: writeStateProc
    command: ["/usr/bin/python3", "-c", "import sys; print('noop')"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
  }

  // Cache of teamId → leagueId, populated by a background full-standings pass.
  FileView {
    id: teamCacheFile
    path: root.cachePath
    watchChanges: false
    printErrors: false
    onLoaded: {
      var parsed = Model.parseJson(String(text() || ""));
      if (parsed && parsed.map) root.teamLeagueMap = parsed.map;
    }
  }

  Process {
    id: allStandingsProc
    command: ["/usr/bin/python3", root.backendPath, "all", "482ofyysbdbeoxauk19yg7tdt"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed || parsed.error) {
          root.pendingLeagueFetches.shift();
          if (root.pendingLeagueFetches.length > 0) {
            var next = root.pendingLeagueFetches.shift();
            allStandingsProc.command = ["/usr/bin/python3", root.backendPath, "all", next];
            allStandingsProc.running = true;
          }
          return;
        }
        var map = Object.assign({}, root.teamLeagueMap);
        var rawTable = Array.isArray(parsed.standings) ? parsed.standings : [];
        for (var i = 0; i < rawTable.length; i++) {
          var r = rawTable[i];
          if (r && r.teamId) map[r.teamId] = parsed.competition;
        }
        root.teamLeagueMap = map;
        // Persist the cache so the next startup doesn't refetch everything.
        writeTeamCache(map);
        if (root.pendingLeagueFetches.length > 0) {
          var next = root.pendingLeagueFetches.shift();
          allStandingsProc.command = ["/usr/bin/python3", root.backendPath, "all", next];
          allStandingsProc.running = true;
        }
      }
    }
  }

  function writeTeamCache(map) {
    teamCacheWriteProc.command = ["/usr/bin/python3", "-c",
      "import json, os, sys\n" +
      "p = sys.argv[1]\n" +
      "d = os.path.dirname(p)\n" +
      "os.makedirs(d, exist_ok=True)\n" +
      "open(p + '.tmp', 'w', encoding='utf-8').write(sys.argv[2])\n" +
      "os.replace(p + '.tmp', p)\n",
      root.cachePath, JSON.stringify({ map: map })]
    teamCacheWriteProc.running = true
  }

  Process {
    id: teamCacheWriteProc
    command: ["/usr/bin/python3", "-c", "import sys; print('noop')"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
  }

  // Onboarding search: type → mackolik contestant search → crest grid.
  Timer {
    id: wizardSearchDebounce
    interval: 280
    repeat: false
    onTriggered: {
      var q = root.wizardQuery.trim()
      if (q.length < 2) { root.wizardResults = []; return }
      root.wizardSearching = true
      wizardSearchProc.command = ["curl", "-fsS", "--max-time", "8",
        "https://www.mackolik.com/ajax/search?keywords=" + encodeURIComponent(q)]
      wizardSearchProc.running = true
    }
  }

  Process {
    id: wizardSearchProc
    command: ["curl", "-fsS", "--max-time", "8", "https://www.mackolik.com/ajax/search?keywords=galatasaray"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.wizardSearching = false
        var parsed = Model.parseJson(String(text || ""))
        var contestants = parsed && parsed.data && parsed.data.results && parsed.data.results.contestants
        var out = []
        if (Array.isArray(contestants)) {
          for (var i = 0; i < contestants.length && out.length < 24; i++) {
            var c = contestants[i]
            if (!c || c.sport !== "Soccer") continue
            out.push({ id: String(c.id || ""), name: Model.clean(c.displayName, 60) })
          }
        }
        root.wizardResults = out
      }
    }
  }

  // UEFA Nations League fixtures for the national team chip.
  Process {
    id: ntProc
    command: ["/usr/bin/python3", root.backendPath, "all", "595nsvo7ykvoe690b1e4u5n56"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed || parsed.error) { root.errorText = strings.t("state.error"); return; }

        var rawMatches = Array.isArray(parsed.matches) ? parsed.matches : [];
        var mkName = Model.ntMkName(root.ntCode);
        var ntRows = [];
        for (var i = 0; i < rawMatches.length; i++) {
          var m = rawMatches[i];
          if (!m) continue;
          var home = Model.clean(m.home, 60), away = Model.clean(m.away, 60);
          if (home !== mkName && away !== mkName) continue;
          var date = String(m.date || "");
          if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
          ntRows.push({
            id: Model.clean(m.id, 64),
            date: date,
            time: /^\d{2}:\d{2}$/.test(String(m.time || "")) ? String(m.time) : "",
            status: m.status === "played" ? "played" : "fixture",
            home: home,
            away: away,
            homeCrest: Model.safeUrl(m.homeCrest),
            awayCrest: Model.safeUrl(m.awayCrest),
            homeScore: Math.max(-1, parseInt(m.homeScore, 10) || -1),
            awayScore: Math.max(-1, parseInt(m.awayScore, 10) || -1)
          });
        }
        root.matches = ntRows;
        root.season = "UEFA Uluslar Ligi";
        root.standings = [];
        root.errorText = "";
        root.lastUpdated = Model.nowTime();
      }
    }
  }

  // Football news for the favourite clubs / national team (Google News RSS, mackolik-only filter).
  property var newsItems: []
  property bool newsLoading: false
  property string newsError: ""

  // In-panel article view state
  property var article: null
  property bool articleLoading: false
  property string articleError: ""

  function refreshNews() {
    var query = root.ntMode ? Model.ntMkName(root.ntCode) : (root.favorites.length > 0 && root.favoriteNames.length > 0 ? root.favoriteNames[0] : (root.ntFavorite ? Model.ntMkName(root.ntFavorite) : Model.leagueShort(root.leagueId)));
    if (!query) return;
    newsLoading = true;
    newsProc.command = ["/usr/bin/python3", root.backendPath, "news", query];
    newsProc.running = true;
  }

  function openArticle(item) {
    if (!item || !item.link) return;
    article = null;
    articleError = "";
    articleLoading = true;
    articleProc.command = ["/usr/bin/python3", root.backendPath, "article", item.link];
    articleProc.running = true;
  }

  function closeArticle() {
    article = null;
    articleError = "";
    articleLoading = false;
  }

  Process {
    id: newsProc
    command: ["/usr/bin/python3", root.backendPath, "news", "Beşiktaş"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.newsLoading = false;
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed || parsed.error) { root.newsError = strings.t("state.error"); return; }
        var out = [];
        var raw = Array.isArray(parsed.items) ? parsed.items : [];
        for (var i = 0; i < raw.length && out.length < 15; i++) {
          var it = raw[i];
          if (!it) continue;
          var link = String(it.link || "");
          var lc = link.toLowerCase();
          if (lc.indexOf("https://www.mackolik.com/") !== 0 && lc.indexOf("https://arsiv.mackolik.com/") !== 0) continue;
          out.push({
            title: Model.clean(it.title, 160),
            link: link,
            pubDate: Model.clean(it.pubDate, 40)
          });
        }
        root.newsItems = out;
        root.newsError = "";
      }
    }
  }

  Process {
    id: articleProc
    command: ["/usr/bin/python3", root.backendPath, "article", "https://www.mackolik.com/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.articleLoading = false;
        var parsed = Model.parseJson(String(text || ""));
        if (!parsed || parsed.error) { root.articleError = strings.t("state.error"); return; }
        var paragraphs = [];
        var raw = Array.isArray(parsed.paragraphs) ? parsed.paragraphs : [];
        for (var i = 0; i < raw.length && paragraphs.length < 40; i++)
          paragraphs.push(Model.clean(raw[i], 900));
        var img = String(parsed.image || "");
        if (img.indexOf("https://") !== 0 || img.indexOf("@") !== -1) img = "";
        root.article = {
          title: Model.clean(parsed.title, 200),
          image: img,
          published: Model.clean(parsed.published, 40),
          paragraphs: paragraphs
        };
        root.articleError = "";
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
      onCloseRequested: { if (root.article) root.closeArticle(); else if (root.detailOpen) root.closeDetail(); else root.close(); }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dy * 46));
      }
      onTextKey: function(t, modifiers) {
        if (t === "r") root.refreshAll(true);
        else if (t === "b") { if (root.article) root.closeArticle(); else if (root.detailOpen) root.closeDetail(); }
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

              // Language re-opener
              Rectangle {
                width: Style.space(38)
                height: Style.space(30)
                radius: Math.min(6, Style.cornerRadius)
                color: languageArea.containsMouse ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
                PlainText {
                  id: languageButtonText
                  anchors.centerIn: parent
                  text: root.languageCode.toUpperCase()
                  color: languageArea.containsMouse ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 0.5
                }
                MouseArea {
                  id: languageArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.onboarded = false; root.wizardStep = 0 }
                }
              }

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

              // National team chip, shown when one is picked
              Rectangle {
                visible: root.ntFavorite !== ""
                readonly property bool selected: root.ntMode
                height: Style.space(28)
                width: ntChipRow.implicitWidth + Style.space(22)
                radius: height / 2
                color: selected ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
                border.width: selected ? 0 : 1
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)

                Row {
                  id: ntChipRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Model.ntFlagPath(root.ntFavorite)
                    sourceSize: Qt.size(48, 32)
                    width: Style.space(17)
                    height: Style.space(12)
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                  }
                  PlainText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: strings.t("nt.chip")
                    color: root.ntMode ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: root.ntMode
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectLeague("nt:" + root.ntFavorite)
                }
              }

              Repeater {
                model: root.sortedLeagues

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

          // ===== Tabs: dynamic (NT mode drops puan durumu; news appears when favourites/NT set)
          Row {
            x: Style.space(16)
            width: parent.width - Style.space(32)
            height: Style.space(38)
            spacing: Style.space(4)

            readonly property var tabModel: {
              var tabs = [
                { id: 0, label: strings.t("tab.today") },
                { id: 1, label: strings.t("tab.tomorrow") },
                { id: 2, label: strings.t("tab.results") }
              ];
              if (!root.ntMode) tabs.push({ id: 3, label: strings.t("tab.table") });
              if (root.favorites.length > 0 || root.ntFavorite !== "") tabs.push({ id: 4, label: strings.t("tab.news") });
              return tabs;
            }

            Repeater {
              model: parent.tabModel

              Item {
                required property var modelData
                required property int index
                readonly property bool selected: modelData.id === root.activeTab
                width: (panelColumn.width - Style.space(32) - (parent.tabModel.length - 1) * Style.space(4)) / parent.tabModel.length
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
                  onClicked: root.selectTab(modelData.id)
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

          // ===== Onboarding wizard (shown until onboarded)
          Item {
            visible: !root.onboarded
            width: parent.width
            implicitHeight: onboardingContent.implicitHeight

            Column {
              id: onboardingContent
              width: parent.width
              spacing: Style.space(14)

              // ---- Step 0: language picker
              Column {
                visible: root.wizardStep === 0
                width: parent.width
                spacing: Style.space(12)

                Column {
                  spacing: 4
                  PlainText {
                    text: strings.t("onb.welcome")
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.displayLarge
                    font.bold: true
                  }
                  PlainText {
                    text: strings.t("onb.language")
                    color: root.fgDim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                  }
                }

                Flickable {
                  width: parent.width
                  height: Style.space(430)
                  contentWidth: width
                  contentHeight: languageGrid.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Grid {
                    id: languageGrid
                    columns: 2
                    spacing: Style.space(8)
                    width: parent.width

                    Repeater {
                      model: Object.keys(Model.languageNames).map(function(code) {
                        return { code: code, name: Model.languageNames[code] }
                      })

                      Rectangle {
                        required property var modelData
                        readonly property bool selected: modelData.code === root.languageCode
                        width: (languageGrid.width - Style.space(8)) / 2
                        height: Style.space(46)
                        radius: Math.min(10, Style.cornerRadius)
                        color: selected ? Style.hoverFillFor(root.fg, root.accent) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                        border.width: selected ? 0 : 1
                        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

                        Row {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.space(14)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(12)
                          PlainText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.code.toUpperCase()
                            color: selected ? Style.hoverStateColor(root.fg, root.accent) : root.fgFaint
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            width: 34
                          }
                          PlainText {
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - Style.space(46)
                            text: modelData.name
                            color: selected ? Style.hoverStateColor(root.fg, root.accent) : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: selected
                          }
                        }
                        MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: { root.applyLanguage(modelData.code); root.saveState(); }
                        }
                      }
                    }
                  }
                }

                Row {
                  width: parent.width
                  anchors.right: parent.right
                  spacing: Style.space(10)
                  Rectangle {
                    width: Style.space(150)
                    height: Style.space(38)
                    radius: Math.min(8, Style.cornerRadius)
                    color: accentFill.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                    PlainText {
                      anchors.centerIn: parent
                      text: strings.t("onb.continue")
                      color: "#ffffff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    MouseArea {
                      id: accentFill
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.wizardStep = 1
                    }
                  }
                }
              }

              // ---- Step 1: favourite clubs (search → crest grid)
              Column {
                visible: root.wizardStep === 1
                width: parent.width
                spacing: Style.space(10)

                PlainText {
                  text: strings.t("onb.favorites")
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                TextField {
                  id: searchField
                  width: parent.width
                  height: Style.space(40)
                  placeholderText: strings.t("onb.search")
                  foreground: root.fg
                  font.family: root.fontFamily
                  onTextChanged: {
                    root.wizardQuery = text
                    wizardSearchDebounce.restart()
                  }
                }
                Item {
                  visible: root.wizardSearching
                  width: parent.width
                  height: Style.space(30)
                  PlainText {
                    anchors.centerIn: parent
                    text: strings.t("state.loading")
                    color: root.fgDim
                    font.pixelSize: Style.font.caption
                  }
                }

                Flickable {
                  width: parent.width
                  height: Style.space(320)
                  contentWidth: width
                  contentHeight: clubGrid.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Grid {
                    id: clubGrid
                    columns: 4
                    spacing: Style.space(8)
                    width: parent.width

                    Repeater {
                      model: root.wizardResults

                      Rectangle {
                        required property var modelData
                        readonly property bool selected: root.favorites.indexOf(modelData.id) !== -1
                        width: (clubGrid.width - Style.space(24)) / 4
                        height: Style.space(86)
                        radius: Math.min(10, Style.cornerRadius)
                        color: selected ? Style.hoverFillFor(root.fg, root.accent) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                        border.width: selected ? 0 : 1
                        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

                        Column {
                          anchors.centerIn: parent
                          spacing: 4
                          Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: modelData.id ? "https://file.mackolikfeeds.com/teams/" + modelData.id : ""
                            sourceSize: Qt.size(56, 56)
                            width: Style.space(34)
                            height: Style.space(34)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                          }
                          PlainText {
                            width: parent.width - Style.space(8)
                            anchors.horizontalCenter: parent.horizontalCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData.name
                            color: selected ? Style.hoverStateColor(root.fg, root.accent) : root.fgDim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: selected
                          }
                        }
                        MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleFavorite(modelData.id)
                        }
                      }
                    }
                  }
                }

                PlainText {
                  text: root.favorites.length + " / " + strings.t("onb.favorites")
                  color: root.fgFaint
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  Item { width: 1; height: 1 }
                  Rectangle {
                    width: Style.space(110)
                    height: Style.space(38)
                    radius: Math.min(8, Style.cornerRadius)
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                    PlainText {
                      anchors.centerIn: parent
                      text: strings.t("onb.skip")
                      color: root.fgDim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.wizardStep = 2
                    }
                  }
                  Rectangle {
                    width: Style.space(150)
                    height: Style.space(38)
                    radius: Math.min(8, Style.cornerRadius)
                    color: root.favorites.length > 0 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
                    PlainText {
                      anchors.centerIn: parent
                      text: strings.t("onb.continue")
                      color: root.favorites.length > 0 ? "#ffffff" : root.fgFaint
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.wizardStep = 2
                    }
                  }
                }
              }

              // ---- Step 2: national team (flags grid)
              Column {
                visible: root.wizardStep === 2
                width: parent.width
                spacing: Style.space(10)

                PlainText {
                  text: strings.t("onb.nt")
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Flickable {
                  width: parent.width
                  height: Style.space(360)
                  contentWidth: width
                  contentHeight: flagGrid.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Grid {
                    id: flagGrid
                    columns: 3
                    spacing: Style.space(8)
                    width: parent.width

                    Repeater {
                      model: Model.nationalTeams
                      Rectangle {
                        required property var modelData
                        readonly property bool selected: root.ntFavorite === modelData.code
                        width: (flagGrid.width - Style.space(16)) / 3
                        height: Style.space(58)
                        radius: Math.min(10, Style.cornerRadius)
                        color: selected ? Style.hoverFillFor(root.fg, root.accent) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                        border.width: selected ? 0 : 1
                        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

                        Row {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.space(10)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(10)
                          Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Model.ntFlagPath(modelData.code)
                            sourceSize: Qt.size(56, 40)
                            width: Style.space(32)
                            height: Style.space(22)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                          }
                          PlainText {
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData.name
                            color: selected ? Style.hoverStateColor(root.fg, root.accent) : root.fg
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            font.bold: selected
                          }
                        }
                        MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.ntFavorite = selected ? "" : modelData.code
                        }
                      }
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  Item { width: 1; height: 1 }
                  Rectangle {
                    width: Style.space(110)
                    height: Style.space(38)
                    radius: Math.min(8, Style.cornerRadius)
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                    PlainText {
                      anchors.centerIn: parent
                      text: strings.t("onb.skip")
                      color: root.fgDim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.finishOnboarding()
                    }
                  }
                  Rectangle {
                    width: Style.space(150)
                    height: Style.space(38)
                    radius: Math.min(8, Style.cornerRadius)
                    color: root.accent
                    PlainText {
                      anchors.centerIn: parent
                      text: strings.t("onb.save")
                      color: "#ffffff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.finishOnboarding()
                    }
                  }
                }
              }
            }
          }

          // ===== In-panel article view
          Item {
            visible: root.article !== null || root.articleLoading || root.articleError !== ""
            width: parent.width
            implicitHeight: (root.article !== null || root.articleLoading || root.articleError !== "") ? articleContent.implicitHeight : 0

            Column {
              id: articleContent
              width: parent.width
              spacing: Style.space(10)

              Item {
                width: parent.width
                height: Style.space(32)

                PlainText {
                  id: articleBackText
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("detail.back")
                  color: articleBackArea.containsMouse ? root.accent : root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                MouseArea {
                  id: articleBackArea
                  anchors.fill: articleBackText
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.closeArticle()
                }
                PlainText {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.article && root.article.published !== ""
                  text: root.article ? root.article.published : ""
                  color: root.fgFaint
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Item {
                visible: root.articleLoading && root.article === null
                width: parent.width
                height: Style.space(80)
                PlainText {
                  anchors.centerIn: parent
                  text: strings.t("state.loading")
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.italic: true
                }
              }

              Item {
                visible: root.articleError !== ""
                width: parent.width
                height: Style.space(50)
                PlainText {
                  anchors.centerIn: parent
                  text: root.articleError
                  color: "#e5a13d"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Column {
                visible: !!root.article
                width: parent.width
                spacing: Style.space(10)

                PlainText {
                  leftPadding: Style.space(18)
                  rightPadding: Style.space(18)
                  width: parent.width
                  wrapMode: Text.Wrap
                  text: root.article ? root.article.title : ""
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Image {
                  visible: root.article && root.article.image !== "" && status !== Image.Error
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width - Style.space(36)
                  height: Math.min(220, width * 0.56)
                  source: root.article ? root.article.image : ""
                  sourceSize: Qt.size(880, 440)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                }

                Flickable {
                  width: parent.width
                  height: Style.space(340)
                  contentWidth: width
                  contentHeight: articleBodyColumn.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Column {
                    id: articleBodyColumn
                    width: parent.width
                    spacing: Style.space(10)

                    Repeater {
                      model: root.article ? root.article.paragraphs : []
                      PlainText {
                        required property var modelData
                        width: parent.width - Style.space(36)
                        x: Style.space(18)
                        wrapMode: Text.Wrap
                        text: modelData
                        color: root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        lineHeight: 1.35
                      }
                    }

                    Item { width: 1; height: Style.space(6) }
                  }
                }
              }
            }
          }

          // ===== Matches list (tabs 0-2)
          Item {
            width: parent.width
            visible: root.onboarded && !root.detailOpen && !root.article && root.activeTab !== 3 && root.activeTab !== 4
            implicitHeight: (root.onboarded && !root.detailOpen && !root.article && root.activeTab !== 3 && root.activeTab !== 4) ? matchesContent.implicitHeight : 0

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

          // ===== News (tab 4, shown when favourites/NT set)
          Item {
            visible: !root.article && root.activeTab === 4
            width: parent.width
            implicitHeight: (!root.article && root.activeTab === 4) ? newsContent.implicitHeight : 0

            Column {
              id: newsContent
              width: parent.width
              spacing: Style.space(4)

              PlainText {
                leftPadding: Style.space(16)
                text: strings.t("tab.news").toUpperCase()
                color: root.fgFaint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.5
                font.bold: true
              }

              Item {
                visible: root.newsLoading && root.newsItems.length === 0
                width: parent.width
                height: Style.space(80)
                PlainText {
                  anchors.centerIn: parent
                  text: strings.t("state.loading")
                  color: root.fgDim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.italic: true
                }
              }

              Item {
                visible: root.newsError !== ""
                width: parent.width
                height: Style.space(60)
                PlainText {
                  anchors.centerIn: parent
                  text: root.newsError
                  color: "#e5a13d"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Repeater {
                model: root.newsItems

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: newsRow.implicitHeight + Style.space(14)
                  color: newsArea.containsMouse
                    ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    : (index % 2 === 0 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03) : "transparent")

                  Column {
                    id: newsRow
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(16)
                    anchors.rightMargin: Style.space(16)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    spacing: 3

                    PlainText {
                      width: parent.width
                      wrapMode: Text.Wrap
                      maximumLineCount: 2
                      elide: Text.ElideRight
                      text: modelData.title
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    PlainText {
                      width: parent.width
                      text: {
                        var d = new Date(modelData.pubDate);
                        return isNaN(d.getTime()) ? modelData.pubDate : d.toLocaleDateString(root.localeTag, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
                      }
                      color: root.fgFaint
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  MouseArea {
                    id: newsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openArticle(modelData)
                  }
                }
              }

              Item { width: 1; height: Style.space(4) }
            }
          }

          // ===== Standings table (tab 3)
          Item {
            visible: root.onboarded && !root.detailOpen && !root.article && root.activeTab === 3
            width: parent.width
            implicitHeight: (root.onboarded && !root.detailOpen && !root.article && root.activeTab === 3) ? tableContent.implicitHeight : 0

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
