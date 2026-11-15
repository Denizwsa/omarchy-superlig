#!/usr/bin/env python3
# superlig.futbol backend — mackolik.com data source.
# Usage: mackolik.py all <competition_id>
# Fetches the league's puan-durumu page once and prints normalized JSON:
#   { competition, season, fetchedAt, standings: [...], matches: [...] }
# On failure prints { "error": "..." } and exits 1.
# No third-party dependencies; stdlib only.

import sys, os, re, json, html as htmllib, time, urllib.request, urllib.error, urllib.parse
import xml.etree.ElementTree as ET

MAX_BYTES = 12 * 1024 * 1024
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
CREST = "https://file.mackolikfeeds.com/teams/%s"


def fail(msg):
    print(json.dumps({"error": str(msg)[:200]}, ensure_ascii=False))
    sys.exit(1)


def fetch(url, tries=3):
    last = "unknown"
    for attempt in range(tries):
        req = urllib.request.Request(
            url,
            headers={"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8"},
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read(MAX_BYTES + 1)
                if len(data) > MAX_BYTES:
                    fail("response too large")
                return data.decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
            if e.code not in (502, 503, 429, 504):
                fail(last)  # permanent, don't hammer
        except Exception as e:
            last = str(e)
        time.sleep(2 + attempt * 2)
    fail(last)


def parse_int(text, default=0):
    try:
        t = text.strip().replace("+", "").replace("−", "-")
        return int(t)
    except Exception:
        return default


def parse_standings(page):
    tbl_at = page.find("p0c-competition-tables__table--total")
    if tbl_at == -1:
        tbl_at = page.find("p0c-competition-tables__table")
    if tbl_at == -1:
        return []
    end = page.find("</tbody>", tbl_at)
    body = page[tbl_at:end if end != -1 else len(page)]
    rows = []
    for m in re.finditer(r'<tr[^>]*p0c-competition-tables__row[^>]*>.*?</tr>', body, re.S):
        row = m.group(0)
        attrs = dict(re.findall(r'data-([a-z\-]+)="([^"]*)"', row))
        name = htmllib.unescape(attrs.get("team-name", "")).strip()
        team_id = attrs.get("team-id", "").strip()
        if not name:
            continue
        rank_m = re.search(r'__rank"\s+data-value>\s*(\d+)\s*<', row)
        rank = int(rank_m.group(1)) if rank_m else 0
        zone = ""
        zm = re.findall(r'--rank-status-(\d+)', row)
        if zm:
            zone = {"1": "champions", "2": "champions", "3": "europa",
                    "4": "conference", "5": "relegation"}.get(zm[0], "")
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.S)

        def cell_text(i, default="0"):
            if i >= len(cells):
                return default
            t = re.sub(r'<[^>]+>', '', cells[i])
            return htmllib.unescape(t).strip().replace("\xa0", " ")

        played = parse_int(cell_text(3))
        # cell 4 is the "+/-" pre-GD column; ignore it
        w, d, l = parse_int(cell_text(5)), parse_int(cell_text(6)), parse_int(cell_text(7))
        gf, ga = parse_int(cell_text(8)), parse_int(cell_text(9))
        gd = parse_int(cell_text(10))
        pts = parse_int(cell_text(11))
        rows.append({
            "rank": rank, "teamId": team_id, "team": name,
            "crest": CREST % team_id if team_id else "",
            "played": played, "win": w, "draw": d, "loss": l,
            "gf": gf, "ga": ga, "gd": gd, "pts": pts,
            "zone": zone, "form": "",
        })
    return rows


def parse_fixtures(page):
    text = page.replace("&quot;", '"')
    out = []
    for m in re.finditer(r'\{"match":\{', text):
        s = m.start()
        depth, i = 0, s
        while i < len(text):
            c = text[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        if depth != 0:
            continue
        try:
            obj = json.loads(text[s:i + 1])
        except Exception:
            continue
        rm = obj.get("match", obj)
        team_a, team_b = rm.get("team_A") or {}, rm.get("team_B") or {}
        a_id, b_id = team_a.get("uuid", ""), team_b.get("uuid", "")
        played = rm.get("status") == "Played"
        out.append({
            "id": str(rm.get("uuid") or rm.get("id") or ""),
            "date": str(rm.get("date_time_utc") or "")[:10],
            "time": str(rm.get("match_time") or "")[:5],
            "status": "played" if played else "fixture",
            "home": team_a.get("name", ""), "away": team_b.get("name", ""),
            "homeId": a_id, "awayId": b_id,
            "homeCrest": CREST % a_id if a_id else "",
            "awayCrest": CREST % b_id if b_id else "",
            "homeScore": parse_int(str(rm.get("fts_A"))) if played else -1,
            "awayScore": parse_int(str(rm.get("fts_B"))) if played else -1,
        })
    out.sort(key=lambda r: (r["date"], r["time"]))
    return out


def compute_form(fixtures, team_id):
    played = [f for f in fixtures if f["status"] == "played" and
              (f["homeId"] == team_id or f["awayId"] == team_id)]
    played.sort(key=lambda r: (r["date"], r["time"]), reverse=True)
    letters = []
    for f in played[:5]:
        hs, aw = f["homeScore"], f["awayScore"]
        if hs == aw:
            letters.append("D")
        elif (f["homeId"] == team_id) == (hs > aw):
            letters.append("W")
        else:
            letters.append("L")
    return "".join(reversed(letters))


def parse_match_page(page):
    text = page.replace("&quot;", '"')
    out = {"events": [], "homeXi": [], "awayXi": [],
           "homeFormation": "", "awayFormation": "", "officials": []}

    out["officials"] = [htmllib.unescape(t).strip() for t in
                        re.findall(r'p0c-match-officials__official-name">\s*([^<]+?)\s*<', page)][:4]

    fm = [htmllib.unescape(t).strip() for t in re.findall(r'Opta-TeamFormation">([^<]+)<', page)]
    if fm:
        out["homeFormation"] = fm[0]
        out["awayFormation"] = fm[1] if len(fm) > 1 else ""

    node = re.compile(r'<g class="Opta-Node (Opta-Home|Opta-Away) Opta-Starter">(.{0,1200}?)(?=<g class="Opta-Node|</svg>)', re.S)
    for m in node.finditer(page):
        side, seg = m.group(1), m.group(2)
        num = re.search(r'Opta-JerseyNumber"[^>]*>\s*(\d+)\s*<', seg)
        name = re.search(r'Opta-PlayerName"[^>]*>([^<]+)<', seg)
        if not name:
            continue
        item = {"num": num.group(1) if num else "", "name": htmllib.unescape(name.group(1)).strip()}
        (out["homeXi"] if side == "Opta-Home" else out["awayXi"]).append(item)

    i = text.find('"keyEvents"')
    if i != -1:
        j = text.find("[", i)
        if j != -1:
            depth, k = 0, j
            while k < len(text):
                c = text[k]
                if c == "[":
                    depth += 1
                elif c == "]":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            try:
                raw_events = json.loads(text[j:k + 1])
            except Exception:
                raw_events = []
            for e in raw_events:
                if not isinstance(e, dict):
                    continue
                etype = e.get("type")
                if etype not in ("goal", "card", "substitute"):
                    continue
                out["events"].append({
                    "type": etype,
                    "subType": str(e.get("subType") or ""),
                    "side": str(e.get("position") or ""),
                    "minute": parse_int(str(e.get("timeMin") or "0")),
                    "player": str(e.get("playerName") or ""),
                    "playerOut": str(e.get("playerOutName") or ""),
                    "assist": str(e.get("assistPlayerName") or ""),
                    "score": str(e.get("score") or ""),
                })
    out["events"].sort(key=lambda e: e["minute"])
    return out



def fetch_news(query):
    # Bing News RSS: source URLs embedded in the apiclick wrapper are directly
    # recoverable, so in-panel article view works without opening a browser.
    q = urllib.parse.quote("site:mackolik.com " + query)
    url = "https://www.bing.com/news/search?q=%s&format=rss" % q
    raw = fetch(url)
    try:
        root = ET.fromstring(raw)
    except Exception as e:
        fail("rss parse: %s" % e)
    items = []
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        pub = (item.findtext("pubDate") or "").strip()
        if not title or not link:
            continue
        # Bing wraps mackolik.com URLs in an apiclick redirector with url=<encoded>.
        target = link
        if "url=" in link:
            target = urllib.parse.unquote(link.split("url=")[-1].split("&")[0])
        if not target.startswith("http"):
            continue
        title = re.sub(r"\s+", " ", title).strip()
        items.append({"title": title, "link": target, "pubDate": pub, "source": "Mackolik"})
        if len(items) >= 15:
            break
    return items


ALLOWED_ARTICLE_HOSTS = {"www.mackolik.com", "mackolik.com", "arsiv.mackolik.com"}


def fetch_article(url):
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    if host not in ALLOWED_ARTICLE_HOSTS:
        fail("unsupported host: %s" % host)
    page = fetch(url)
    text = page

    def meta(prop):
        m = re.search(r'<meta[^>]+(?:property|name)="%s"[^>]+content="([^"]*)"' % re.escape(prop), text, re.I)
        return htmllib.unescape(m.group(1)).strip() if m else ""

    title = meta("og:title") or re.findall(r"<title>(.*?)</title>", text, re.S)[0] if re.findall(r"<title>(.*?)</title>", text, re.S) else ""
    title = re.sub(r"\s*[|@]\s*Mackolik\.com\s*$", "", htmllib.unescape(title)).strip()

    image = meta("og:image")
    published = meta("article:published_time") or meta("datePublished") or meta("og:updated_time")

    # Paragraphs live in the articleBody block; strip tags and keep plain text.
    i = text.find("articleBody")
    zone = text[i:] if i != -1 else text
    body_end = zone.find("</body>")
    if body_end != -1:
        zone = zone[:body_end]
    paragraphs = []
    for m in re.finditer(r"<p[^>]*>(.*?)</p>", zone, re.S | re.I):
        p = re.sub(r"<[^>]+>", "", m.group(1))
        p = htmllib.unescape(p)
        p = re.sub(r"\s+", " ", p).strip()
        if len(p) >= 30:
            paragraphs.append(p[:800])
        if len(paragraphs) >= 40:
            break

    return {"title": title, "image": image, "published": published, "paragraphs": paragraphs}


def main():
    if len(sys.argv) < 3:
        fail("usage: mackolik.py all <competition_id> | mackolik.py match <match_id>")

    mode = sys.argv[1]
    target = sys.argv[2].strip()

    if mode == "news":
        if not re.fullmatch(r".{2,80}", target):
            fail("bad query")
        print(json.dumps({"query": target, "items": fetch_news(target)}, ensure_ascii=False))
        return

    if mode == "article":
        print(json.dumps(fetch_article(target), ensure_ascii=False))
        return

    if mode == "all":
        if not re.fullmatch(r"[A-Za-z0-9]{10,40}", target):
            fail("bad competition id")
        page = fetch("https://www.mackolik.com/r/lig/%s" % target)

        season = ""
        m = re.search(r"puan-durumu/[^\"']*(20\d\d-20\d\d)", page)
        if m:
            season = m.group(1)

        standings = parse_standings(page)
        matches = parse_fixtures(page)
        for row in standings:
            row["form"] = compute_form(matches, row["teamId"])

        print(json.dumps({
            "competition": target,
            "season": season,
            "fetchedAt": int(time.time() * 1000),
            "standings": standings,
            "matches": matches,
        }, ensure_ascii=False))
        return

    if mode == "match":
        if not re.fullmatch(r"[A-Za-z0-9]{10,64}", target):
            fail("bad match id")
        # Bare "x" slug redirects to the canonical match URL.
        page = fetch("https://www.mackolik.com/mac/x/%s" % target)
        detail = parse_match_page(page)
        detail["matchId"] = target
        detail["fetchedAt"] = int(time.time() * 1000)
        print(json.dumps(detail, ensure_ascii=False))
        return

    fail("unknown mode: %s" % mode)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        fail(e)
