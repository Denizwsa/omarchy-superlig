# Futbol — Omarchy plugin

Maçkolik-style football for the Omarchy bar and popup panel. Live scores with minute:second, fixtures, full league tables with crests, match details — now with favourites, a first-run onboarding, and 50 languages.

## First run

1. **Language** — the whole plugin switches to the chosen language (50 languages included; fallback is English)
2. **Your favourite clubs** — search-and-pick across all leagues (search "Beşiktaş", tap the crest)
3. **Your national team** — flag grid, multi-select not required; pick the one you follow

Persist in `~/.local/state/omarchy/superlig.futbol/state.json`. Re-open the wizard anytime from the language button in the panel header.

## Features

- **Bar pill**: ball icon when nothing's on; when one of your favourite clubs or your national team is playing, it shows crests + live score + minute (e.g. `Bjk 2 : 1 GS 78'`)
- **Leagues (20):** Süper Lig, TFF 1./2./3. Lig, Premier League, Championship, League One/Two, LaLiga (+ LaLiga 2), Serie A, Bundesliga, 2. Bundesliga, Ligue 1, Eredivisie (+ Eerste Divisie), Primeira Liga, UEFA Champions/Europa/Conference League
- **Bugün / Yarın / Sonuçlar / Puan Durumu** — favorites-first league ordering (cached), zone colours (ŞL/Avrupa/küme), form pills
- **Match details** — events timeline, starting XIs with formations, officials
- **Re-ordered chips** — your favourite leagues float to the top; language choice re-prioritises the list too
- **50 languages** — UI fully localised; switch anytime from the panel header

## Install

```sh
omarchy plugin add https://github.com/Denizwsa/omarchy-superlig.git
```

Uninstall:

```sh
omarchy plugin remove superlig.futbol
```

State and cache:

```sh
rm -rf ~/.local/state/omarchy/superlig.futbol
```

## Dependencies

- Omarchy shell (Quickshell) — plugin runtime
- `curl` and `python3` (stdlib only) — shipped with Omarchy

## Data source

Unofficial client of **mackolik.com** (not affiliated with mackolik). League fixtures and tables from the league pages (`/r/lig/<id>`); live state from the daily livescores JSON. Requests happen only when the panel opens and while it is open (auto-refresh, default 10 min) — a few requests per refresh, a few MB per league load. A polite UA is sent; rate-limited responses keep last-good data on screen.

Team crests: `https://file.mackolikfeeds.com/teams/<uuid>`. Flags: flagcdn.com SVGs (bundled).

## Limits

- No substitutions bench; officials shown, manager not embedded
- Live minute computed from the feed's period timestamps; extra-time minute may read high
- Some competitions (national cups) may not expose tables on mackolik's public pages
- Favourite → league mapping is cached after the first full standings sweep (~20 pages, one time)

## License

MIT — see [LICENSE](LICENSE).
