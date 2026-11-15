.pragma library

// Shared helpers for superlig.futbol. The python backend (backend/mackolik.py)
// does network + parsing; this file keeps display-side helpers only.

var MAX_RAW = 2 * 1024 * 1024; // backend output is small; cap anyway

function clean(value, maxLen) {
  if (value === undefined || value === null) return "";
  var s = String(value);
  var limit = maxLen || 80;
  if (s.length > limit) s = s.slice(0, limit);
  s = s.replace(/[\u0000-\u001f\u007f]/g, " ").trim();
  return s;
}

// Team crests come from exactly one host.
function safeUrl(value) {
  if (!value) return "";
  var s = String(value).trim();
  if (s.length > 256) return "";
  if (s.indexOf("https://file.mackolikfeeds.com/teams/") !== 0) return "";
  return s;
}

function parseJson(raw) {
  var text = String(raw || "").trim();
  if (!text || text.length > MAX_RAW) return null;
  try {
    return JSON.parse(text);
  } catch (e) {
    return null;
  }
}

function pad2(n) { return (n < 10 ? "0" : "") + n; }

function isoDate(offsetDays) {
  var d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
}
function todayISO() { return isoDate(0); }
function tomorrowISO() { return isoDate(1); }
function nowTime() {
  var d = new Date();
  return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
}

function matchesOnDate(matches, dateISO, cap) {
  var rows = [];
  if (!Array.isArray(matches)) return rows;
  for (var i = 0; i < matches.length && rows.length < (cap || 40); i++) {
    var m = matches[i];
    if (m && m.date === dateISO && typeof m === "object") rows.push(m);
  }
  return rows;
}

function playedDesc(matches, cap) {
  var rows = [];
  if (!Array.isArray(matches)) return rows;
  for (var i = matches.length - 1; i >= 0 && rows.length < (cap || 12); i--) {
    var m = matches[i];
    if (m && m.status === "played") rows.push(m);
  }
  return rows;
}

// Live overlay from the daily livescores feed (state/substate per match uuid).
// One entry per match id; absent ids are simply not live.
function parseLiveFeed(payload) {
  var out = {};
  var matches = payload && payload.data && payload.data.matches;
  if (!matches || typeof matches !== "object") return out;
  var count = 0;
  for (var id in matches) {
    if (count >= 4000) break;
    if (!Object.prototype.hasOwnProperty.call(matches, id)) continue;
    var m = matches[id];
    if (!m) continue;
    var score = m.score || {};
    var ht = score.ht || {};
    out[id] = {
      state: String(m.state || ""),
      substate: String(m.substate || "none"),
      periodId: parseInt(m.periodId, 10) || 0,
      periodStart: parseInt(m.periodStart, 10) || 0,
      homeScore: parseInt(score.home, 10),
      awayScore: parseInt(score.away, 10),
      htHome: parseInt(ht.home, 10),
      htAway: parseInt(ht.away, 10)
    };
    if (isNaN(out[id].homeScore)) out[id].homeScore = -1;
    if (isNaN(out[id].awayScore)) out[id].awayScore = -1;
    if (isNaN(out[id].htHome)) out[id].htHome = -1;
    if (isNaN(out[id].htAway)) out[id].htAway = -1;
    count++;
  }
  return out;
}

// Curated league list. Ids are mackolik.com competition ids.
var leagues = [
  { id: "482ofyysbdbeoxauk19yg7tdt", name: "Trendyol Süper Lig", short: "Süper Lig" },
  { id: "2o9svokc5s7diish3ycrzk7jm", name: "Trendyol 1. Lig", short: "1. Lig" },
  { id: "2nttcoriwf5co73vmz1vr8frm", name: "Nesine 2. Lig", short: "2. Lig" },
  { id: "907l7wtxdvugdo9i2249wcmr0", name: "Nesine 3. Lig", short: "3. Lig" },
  { id: "2kwbbcootiqqgmrzs6o5inle5", name: "Premier League", short: "Premier Lig" },
  { id: "7ntvbsyq31jnzoqoa8850b9b8", name: "EFL Championship", short: "Championship" },
  { id: "3frp1zxrqulrlrnk503n6l4l", name: "EFL League One", short: "League One" },
  { id: "bgen5kjer2ytfp7lo9949t72g", name: "EFL League Two", short: "League Two" },
  { id: "34pl8szyvrbwcmfkuocjm3r6t", name: "LaLiga", short: "LaLiga" },
  { id: "1r097lpxe0xn03ihb7wi98kao", name: "Serie A", short: "Serie A" },
  { id: "6by3h89i2eykc341oz7lv1ddd", name: "Bundesliga", short: "Bundesliga" },
  { id: "722fdbecxzcq9788l6jqclzlw", name: "2. Bundesliga", short: "2. Bundesliga" },
  { id: "dm5ka0os1e3dxcp3vh05kmp33", name: "Ligue 1", short: "Ligue 1" },
  { id: "akmkihra9ruad09ljapsm84b3", name: "Eredivisie", short: "Eredivisie" },
  { id: "8yi6ejjd1zudcqtbn07haahg6", name: "Liga Portugal", short: "Primeira Liga" },
  { id: "4oogyu6o156iphvdvphwpck10", name: "UEFA Şampiyonlar Ligi", short: "Şampiyonlar Ligi" },
  { id: "4c1nfi2j1m731hcay25fcgndq", name: "UEFA Avrupa Ligi", short: "Avrupa Ligi" },
  { id: "c7b8o53flg36wbuevfzy3lb10", name: "UEFA Konferans Ligi", short: "Konferans Ligi" }
];

function leagueName(id, fallback) {
  for (var i = 0; i < leagues.length; i++)
    if (leagues[i].id === id) return leagues[i].name;
  return fallback || id;
}
function leagueShort(id) {
  for (var i = 0; i < leagues.length; i++)
    if (leagues[i].id === id) return leagues[i].short;
  return id;
}
