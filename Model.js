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
  { id: "3is4bkgf3loxv9qfg3hm8zfqb", name: "LaLiga 2", short: "LaLiga 2" },
  { id: "1r097lpxe0xn03ihb7wi98kao", name: "Serie A", short: "Serie A" },
  { id: "6by3h89i2eykc341oz7lv1ddd", name: "Bundesliga", short: "Bundesliga" },
  { id: "722fdbecxzcq9788l6jqclzlw", name: "2. Bundesliga", short: "2. Bundesliga" },
  { id: "dm5ka0os1e3dxcp3vh05kmp33", name: "Ligue 1", short: "Ligue 1" },
  { id: "akmkihra9ruad09ljapsm84b3", name: "Eredivisie", short: "Eredivisie" },
  { id: "1gwajyt0pk2jm5fx5mu36v114", name: "Eerste Divisie", short: "Eerste Divisie" },
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

// ---- Onboarding / language ------------------------------------------

// Omarchy's 50 registry codes + flag files for onboarding national-team grid.
var languageNames = {
  "en": "English", "ar": "العربية", "bg": "Български", "bn": "বাংলা", "ca": "Català",
  "cs": "Čeština", "da": "Dansk", "de": "Deutsch", "el": "Ελληνικά", "es-MX": "Español (MX)",
  "et": "Eesti", "fa": "فارسی", "fi": "Suomi", "fil": "Filipino", "fr": "Français",
  "ga": "Gaeilge", "he": "עברית", "hi": "हिन्दी", "hr": "Hrvatski", "hu": "Magyar",
  "id": "Indonesia", "is": "Íslenska", "it": "Italiano", "ja": "日本語", "ko": "한국어",
  "lt": "Lietuvių", "lv": "Latviešu", "ms": "Bahasa Melayu", "nl": "Nederlands", "no": "Norsk",
  "pl": "Polski", "pt": "Português", "pt-BR": "Português (BR)", "ro": "Română", "ru": "Русский",
  "si": "සිංහල", "sk": "Slovenčina", "sl": "Slovenščina", "sr": "Srpski", "sv": "Svenska",
  "sw": "Kiswahili", "ta": "தமிழ்", "th": "ไทย", "tr": "Türkçe", "uk": "Українська",
  "ur": "اردو", "uz": "O‘zbek", "vi": "Tiếng Việt", "zh-CN": "简体中文", "zh-TW": "繁體中文"
};

// Leagues ordered to front for each language, most football-adjacent first.
var LANGUAGE_PRIORITY = {
  "tr": ["482ofyysbdbeoxauk19yg7tdt", "2o9svokc5s7diish3ycrzk7jm", "2nttcoriwf5co73vmz1vr8frm", "907l7wtxdvugdo9i2249wcmr0"],
  "en": ["2kwbbcootiqqgmrzs6o5inle5", "7ntvbsyq31jnzoqoa8850b9b8", "3frp1zxrqulrlrnk503n6l4l", "bgen5kjer2ytfp7lo9949t72g"],
  "pt": ["8yi6ejjd1zudcqtbn07haahg6", "34pl8szyvrbwcmfkuocjm3r6t", "1r097lpxe0xn03ihb7wi98kao"],
  "pt-BR": ["8yi6ejjd1zudcqtbn07haahg6", "34pl8szyvrbwcmfkuocjm3r6t", "6by3h89i2eykc341oz7lv1ddd"],
  "es-MX": ["34pl8szyvrbwcmfkuocjm3r6t", "482ofyysbdbeoxauk19yg7tdt", "1r097lpxe0xn03ihb7wi98kao"],
  "it": ["1r097lpxe0xn03ihb7wi98kao", "34pl8szyvrbwcmfkuocjm3r6t", "6by3h89i2eykc341oz7lv1ddd", "dm5ka0os1e3dxcp3vh05kmp33"],
  "de": ["6by3h89i2eykc341oz7lv1ddd", "722fdbecxzcq9788l6jqclzlw", "dkarmrybx9vx10rg7cywumth0", "482ofyysbdbeoxauk19yg7tdt"],
  "fr": ["dm5ka0os1e3dxcp3vh05kmp33", "nomyihforrpqj84kx7ts42cq1", "6by3h89i2eykc341oz7lv1ddd", "1r097lpxe0xn03ihb7wi98kao"],
  "nl": ["akmkihra9ruad09ljapsm84b3", "1gwajyt0pk2jm5fx5mu36v114", "6by3h89i2eykc341oz7lv1ddd", "2kwbbcootiqqgmrzs6o5inle5"]
};
// Turkish Süper Lig ids used as fallback priority for latin/arabic etc.
var DEFAULT_PRIORITY = ["482ofyysbdbeoxauk19yg7tdt", "2kwbbcootiqqgmrzs6o5inle5", "34pl8szyvrbwcmfkuocjm3r6t", "1r097lpxe0xn03ihb7wi98kao", "6by3h89i2eykc341oz7lv1ddd", "dm5ka0os1e3dxcp3vh05kmp33"];

function languagePriority(lang) {
  var key = String(lang || "").toLowerCase();
  var pref = LANGUAGE_PRIORITY[key] || (LANGUAGE_PRIORITY[key.split("-")[0]] || DEFAULT_PRIORITY);
  return pref;
}

// Leagues sorted with favorites first, then language priority, then original order.
function sortLeagues(leagues, favoriteIds, lang) {
  var fav = {};
  for (var i = 0; i < favoriteIds.length; i++) fav[favoriteIds[i]] = true;
  var pref = languagePriority(lang);
  var rank = {};
  for (var j = 0; j < pref.length; j++) rank[pref[j]] = j;

  var decorated = [];
  for (var k = 0; k < leagues.length; k++) {
    var lg = leagues[k];
    var favScore = 0;
    // A league is promoted if the user marked at least one favourite team in it.
    // We don't know per-team league here; promote by priority + later refinement in panel.
    decorated.push({ lg: lg, rank: rank[lg.id] !== undefined ? rank[lg.id] : 1000 + k });
  }
  decorated.sort(function(a, b) { return a.rank - b.rank; });
  var out = [];
  for (var m = 0; m < decorated.length; m++) out.push(decorated[m].lg);
  return out;
}

// Onboarding national-team grid: flag svg path (relative to flags/) + English name.
var nationalTeams = [
  { code: "tr", name: "Türkiye" }, { code: "de", name: "Germany" }, { code: "es", name: "Spain" },
  { code: "fr", name: "France" }, { code: "it", name: "Italy" },
  { code: "pt", name: "Portugal" }, { code: "nl", name: "Netherlands" }, { code: "be", name: "Belgium" },
  { code: "gb-eng", name: "England" }, { code: "gb-sct", name: "Scotland" },
  { code: "br", name: "Brazil" }, { code: "ar", name: "Argentina" }, { code: "us", name: "United States" },
  { code: "mx", name: "Mexico" }, { code: "jp", name: "Japan" }, { code: "kr", name: "South Korea" },
  { code: "sa", name: "Saudi Arabia" }, { code: "au", name: "Australia" }, { code: "ma", name: "Morocco" },
  { code: "dz", name: "Algeria" }, { code: "qa", name: "Qatar" }, { code: "ae", name: "UAE" },
  { code: "cr", name: "Costa Rica" }, { code: "eg", name: "Egypt" }, { code: "tn", name: "Tunisia" },
  { code: "ly", name: "Libya" }, { code: "pl", name: "Poland" }, { code: "ua", name: "Ukraine" },
  { code: "at", name: "Austria" }, { code: "ch", name: "Switzerland" }, { code: "gr", name: "Greece" },
  { code: "cz", name: "Czechia" }, { code: "sk", name: "Slovakia" }, { code: "hu", name: "Hungary" },
  { code: "ro", name: "Romania" }, { code: "bg", name: "Bulgaria" }, { code: "hr", name: "Croatia" },
  { code: "rs", name: "Serbia" }, { code: "si", name: "Slovenia" }, { code: "se", name: "Sweden" },
  { code: "no", name: "Norway" }, { code: "dk", name: "Denmark" }, { code: "fi", name: "Finland" },
  { code: "is", name: "Iceland" }, { code: "ie", name: "Ireland" }, { code: "ca", name: "Canada" },
  { code: "ge", name: "Georgia" }, { code: "az", name: "Azerbaijan" }, { code: "md", name: "Moldova" },
  { code: "ba", name: "Bosnia" }, { code: "al", name: "Albania" }, { code: "mk", name: "North Macedonia" },
  { code: "il", name: "Israel" }
];

function ntFlagPath(code) { return Qt.resolvedUrl("flags/" + code + ".svg"); }

// ---- National teams ---------------------------------------------------

var NT_MK_NAMES = {
  "tr": "Türkiye", "de": "Almanya", "es": "İspanya", "it": "İtalya", "fr": "Fransa",
  "pt": "Portekiz", "nl": "Hollanda", "be": "Belçika", "gb-eng": "İngiltere", "gb-sct": "İskoçya",
  "br": "Brezilya", "ar": "Arjantin", "us": "ABD", "mx": "Meksika", "jp": "Japonya",
  "kr": "Güney Kore", "sa": "Suudi Arabistan", "au": "Avustralya", "ma": "Fas", "dz": "Cezayir",
  "qa": "Katar", "ae": "BAE", "cr": "Kosta Rika", "eg": "Mısır", "tn": "Tunus", "ly": "Libya",
  "pl": "Polonya", "ua": "Ukrayna", "at": "Avusturya", "ch": "İsviçre", "gr": "Yunanistan",
  "cz": "Çekya", "sk": "Slovakya", "hu": "Macaristan", "ro": "Romanya", "bg": "Bulgaristan",
  "hr": "Hırvatistan", "rs": "Sırbistan", "si": "Slovenya", "se": "İsveç", "no": "Norveç",
  "dk": "Danimarka", "fi": "Finlandiya", "is": "İzlanda", "ie": "İrlanda", "ca": "Kanada",
  "ge": "Gürcistan", "az": "Azerbaycan", "md": "Moldova", "ba": "Bosna-Hersek", "al": "Arnavutluk",
  "mk": "Kuzey Makedonya", "il": "İsrail"
};

// Members of the current UEFA Nations League (so the NT chip can show fixtures).
var NT_UEFA = {
  "tr": 1, "de": 1, "es": 1, "it": 1, "fr": 1, "pt": 1, "nl": 1, "be": 1, "gb-eng": 1, "gb-sct": 1,
  "is": 1, "ie": 1, "at": 1, "ch": 1, "gr": 1, "cz": 1, "sk": 1, "hu": 1, "ro": 1, "bg": 1,
  "hr": 1, "rs": 1, "si": 1, "se": 1, "no": 1, "dk": 1, "fi": 1, "pl": 1, "ua": 1, "il": 1,
  "md": 1, "ge": 1, "az": 1, "ba": 1, "al": 1, "mk": 1, "kz": 1, "by": 1, "lt": 1, "lv": 1, "ee": 1
};

function ntMkName(code) { return NT_MK_NAMES[code] || code; }
function ntIsUefa(code) { return NT_UEFA[code] === 1; }

// Filter matches to those involving the given NT (match by mackolik Turkish name).
function filterNtMatches(matches, code) {
  var mk = ntMkName(code);
  var out = [];
  if (!Array.isArray(matches)) return out;
  for (var i = 0; i < matches.length; i++) {
    var m = matches[i];
    if (m && (m.home === mk || m.away === mk)) out.push(m);
  }
  return out;
}

function ntCodeForMkName(name) {
  for (var code in NT_MK_NAMES)
    if (NT_MK_NAMES[code] === name) return code;
  return "";
}
