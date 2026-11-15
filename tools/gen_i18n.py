#!/usr/bin/env python3
# Generates i18n/<locale>.json for superlig.futbol from a master table.
# Untranslated keys fall back to English.
import json, os

CODES = ["ar","bg","bn","ca","cs","da","de","el","en","es-MX","et","fa","fi","fil","fr","ga","he","hi","hr","hu","id","is","it","ja","ko","lt","lv","ms","nl","no","pl","pt","pt-BR","ro","ru","si","sk","sl","sr","sv","sw","ta","th","tr","uk","ur","uz","vi","zh-CN","zh-TW"]

# fmt: each value is a full sentence template or fixed label; %1 placeholders kept.
T = {}

# Base English, then overrides per language.
T["en"] = {
  "panel.title": "Football",
  "tab.today": "Today", "tab.tomorrow": "Tomorrow", "tab.results": "Results", "tab.table": "Table",
  "state.loading": "Loading…", "state.emptyToday": "No matches today", "state.emptyTomorrow": "No matches scheduled tomorrow",
  "state.emptyResults": "No results found", "state.emptyTable": "Standings unavailable",
  "state.error": "Couldn't fetch data — showing last known state",
  "match.ft": "FT", "match.live": "LIVE",
  "col.team": "Team", "col.played": "P", "col.won": "W", "col.drawn": "D", "col.lost": "L",
  "col.gf": "GF", "col.ga": "GA", "col.gd": "GD", "col.pts": "Pts", "col.form": "Form",
  "table.season": "Season %1", "legend.champions": "Champions League", "legend.europe": "European qualification",
  "legend.relegation": "Relegation",
  "foot.source": "Source: mackolik.com", "foot.updated": "Updated %1",
  "action.refresh": "Refresh",
  "detail.back": "‹ Matches", "detail.events": "Match Events", "detail.firstxi": "Starting XIs",
  "detail.officials": "Officials", "detail.notPlayed": "Match hasn't been played yet",
  "ev.goal": "GOAL", "ev.assist": "assist: %1", "ev.yc": "YELLOW CARD", "ev.rc": "RED CARD",
  "ev.subIn": "On: %1", "ev.subOut": "Off: %1",
  "onb.welcome": "Welcome to Futbol", "onb.language": "Choose your language",
  "onb.favorites": "Choose your favourite teams", "onb.nt": "Choose your national team",
  "onb.continue": "Continue", "onb.skip": "Skip", "onb.save": "Save", "onb.search": "Search teams…",
  "onb.done": "All set",
  "nt.chip": "National team",
  "tab.news": "News"
}
T["tr"] = {
  "panel.title": "Futbol",
  "tab.today": "Bugün", "tab.tomorrow": "Yarın", "tab.results": "Son Sonuçlar", "tab.table": "Puan Durumu",
  "state.loading": "Yükleniyor…", "state.emptyToday": "Bugün maç yok", "state.emptyTomorrow": "Yarın için maç bulunamadı",
  "state.emptyResults": "Son sonuç bulunamadı", "state.emptyTable": "Puan durumu alınamadı",
  "state.error": "Veri alınamadı — son bilinen durum gösteriliyor",
  "match.ft": "MS", "match.live": "CANLI",
  "col.team": "Takım", "col.played": "O", "col.won": "G", "col.drawn": "B", "col.lost": "M",
  "col.gf": "AG", "col.ga": "YG", "col.gd": "AV", "col.pts": "P", "col.form": "F",
  "table.season": "Sezon %1", "legend.champions": "Şampiyonlar Ligi", "legend.europe": "Avrupa kupaları",
  "legend.relegation": "Küme düşme",
  "foot.source": "Kaynak: mackolik.com", "foot.updated": "Son güncelleme: %1",
  "action.refresh": "Yenile",
  "detail.back": "‹ Maçlar", "detail.events": "Maç Olayları", "detail.firstxi": "İlk 11'ler",
  "detail.officials": "Hakemler", "detail.notPlayed": "Maç henüz oynanmadı",
  "ev.goal": "GOL", "ev.assist": "asist: %1", "ev.yc": "SARI KART", "ev.rc": "KIRMIZI KART",
  "ev.subIn": "Girdi: %1", "ev.subOut": "Çıktı: %1",
  "onb.welcome": "Futbol'a hoş geldin", "onb.language": "Dilini seç",
  "onb.favorites": "Favori takımlarını seç", "onb.nt": "Millî takımını seç",
  "onb.continue": "Devam", "onb.skip": "Atla", "onb.save": "Kaydet", "onb.search": "Takım ara…",
  "onb.done": "Hazır",
  "nt.chip": "Millî Takım",
  "tab.news": "Haberler"
}

T["es"] = {
  "panel.title": "Fútbol",
  "tab.today": "Hoy", "tab.tomorrow": "Mañana", "tab.results": "Resultados", "tab.table": "Clasificación",
  "state.loading": "Cargando…", "state.emptyToday": "No hay partidos hoy", "state.emptyTomorrow": "No hay partidos programados mañana",
  "state.emptyResults": "No hay resultados", "state.emptyTable": "Clasificación no disponible",
  "state.error": "No se pudieron obtener los datos — mostrando el último estado",
  "match.ft": "FIN", "match.live": "EN VIVO",
  "col.team": "Equipo", "col.played": "PJ", "col.won": "G", "col.drawn": "E", "col.lost": "P",
  "col.gf": "GF", "col.ga": "GC", "col.gd": "DG", "col.pts": "Pts", "col.form": "Forma",
  "table.season": "Temporada %1", "legend.champions": "Liga de Campeones", "legend.europe": "Clasificación europea",
  "legend.relegation": "Descenso",
  "foot.source": "Fuente: mackolik.com", "foot.updated": "Actualizado: %1",
  "action.refresh": "Actualizar",
  "detail.back": "‹ Partidos", "detail.events": "Incidencias", "detail.firstxi": "Alineaciones",
  "detail.officials": "Árbitros", "detail.notPlayed": "El partido aún no se ha jugado",
  "ev.goal": "GOL", "ev.assist": "asist.: %1", "ev.yc": "TARJETA AMARILLA", "ev.rc": "TARJETA ROJA",
  "ev.subIn": "Entra: %1", "ev.subOut": "Sale: %1",
  "onb.welcome": "Bienvenido a Fútbol", "onb.language": "Elige tu idioma",
  "onb.favorites": "Elige tus equipos favoritos", "onb.nt": "Elige tu selección nacional",
  "onb.continue": "Continuar", "onb.skip": "Omitir", "onb.save": "Guardar", "onb.search": "Buscar equipos…",
  "onb.done": "Listo"
}
T["es-MX"] = dict(T["es"]); T["es-MX"].update({"tab.today": "Hoy", "tab.table": "Tabla", "state.emptyToday": "No hay partidos hoy"})
T["it"] = {
  "panel.title": "Calcio",
  "tab.today": "Oggi", "tab.tomorrow": "Domani", "tab.results": "Risultati", "tab.table": "Classifica",
  "state.loading": "Caricamento…", "state.emptyToday": "Nessuna partita oggi", "state.emptyTomorrow": "Nessuna partita programmata domani",
  "state.emptyResults": "Nessun risultato", "state.emptyTable": "Classifica non disponibile",
  "state.error": "Impossibile recuperare i dati — mostro l'ultimo stato noto",
  "match.ft": "FINE", "match.live": "LIVE",
  "col.team": "Squadra", "col.played": "PG", "col.won": "V", "col.drawn": "N", "col.lost": "P",
  "col.gf": "GF", "col.ga": "GA", "col.gd": "DR", "col.pts": "Pt", "col.form": "Forma",
  "table.season": "Stagione %1", "legend.champions": "Champions League", "legend.europe": "Qualificazione europea",
  "legend.relegation": "Retrocessione",
  "foot.source": "Fonte: mackolik.com", "foot.updated": "Aggiornato: %1",
  "action.refresh": "Aggiorna",
  "detail.back": "‹ Partite", "detail.events": "Cronaca", "detail.firstxi": "Formazioni",
  "detail.officials": "Arbitri", "detail.notPlayed": "La partita non è ancora stata giocata",
  "ev.goal": "GOL", "ev.assist": "assist: %1", "ev.yc": "AMMONIZIONE", "ev.rc": "ESPULSIONE",
  "ev.subIn": "Entra: %1", "ev.subOut": "Esce: %1",
  "onb.welcome": "Benvenuto in Calcio", "onb.language": "Scegli la lingua",
  "onb.favorites": "Scegli le tue squadre del cuore", "onb.nt": "Scegli la tua nazionale",
  "onb.continue": "Continua", "onb.skip": "Salta", "onb.save": "Salva", "onb.search": "Cerca squadre…",
  "onb.done": "Fatto"
}
T["de"] = {
  "panel.title": "Fußball",
  "tab.today": "Heute", "tab.tomorrow": "Morgen", "tab.results": "Ergebnisse", "tab.table": "Tabelle",
  "state.loading": "Lädt…", "state.emptyToday": "Heute keine Spiele", "state.emptyTomorrow": "Morgen keine Spiele angesetzt",
  "state.emptyResults": "Keine Ergebnisse", "state.emptyTable": "Tabelle nicht verfügbar",
  "state.error": "Daten konnten nicht geladen werden — letzter bekannter Stand wird angezeigt",
  "match.ft": "ABPFIFF", "match.live": "LIVE",
  "col.team": "Verein", "col.played": "Sp", "col.won": "S", "col.drawn": "U", "col.lost": "N",
  "col.gf": "T+", "col.ga": "T−", "col.gd": "Diff", "col.pts": "Pkt", "col.form": "Form",
  "table.season": "Saison %1", "legend.champions": "Champions League", "legend.europe": "Europapokal",
  "legend.relegation": "Abstieg",
  "foot.source": "Quelle: mackolik.com", "foot.updated": "Aktualisiert: %1",
  "action.refresh": "Aktualisieren",
  "detail.back": "‹ Spiele", "detail.events": "Spielverlauf", "detail.firstxi": "Aufstellungen",
  "detail.officials": "Schiedsrichter", "detail.notPlayed": "Das Spiel steht noch aus",
  "ev.goal": "TOR", "ev.assist": "Vorlage: %1", "ev.yc": "GELBE KARTE", "ev.rc": "ROTE KARTE",
  "ev.subIn": "Rein: %1", "ev.subOut": "Raus: %1",
  "onb.welcome": "Willkommen bei Fußball", "onb.language": "Sprache wählen",
  "onb.favorites": "Wähle deine Lieblingsvereine", "onb.nt": "Wähle deine Nationalmannschaft",
  "onb.continue": "Weiter", "onb.skip": "Überspringen", "onb.save": "Speichern", "onb.search": "Vereine suchen…",
  "onb.done": "Fertig"
}
T["fr"] = {
  "panel.title": "Football",
  "tab.today": "Aujourd'hui", "tab.tomorrow": "Demain", "tab.results": "Résultats", "tab.table": "Classement",
  "state.loading": "Chargement…", "state.emptyToday": "Aucun match aujourd'hui", "state.emptyTomorrow": "Aucun match prévu demain",
  "state.emptyResults": "Aucun résultat", "state.emptyTable": "Classement indisponible",
  "state.error": "Impossible de charger les données — dernier état connu affiché",
  "match.ft": "FIN", "match.live": "EN DIRECT",
  "col.team": "Équipe", "col.played": "J", "col.won": "V", "col.drawn": "N", "col.lost": "D",
  "col.gf": "BP", "col.ga": "BC", "col.gd": "Diff", "col.pts": "Pts", "col.form": "Forme",
  "table.season": "Saison %1", "legend.champions": "Ligue des Champions", "legend.europe": "Qualification européenne",
  "legend.relegation": "Relégation",
  "foot.source": "Source : mackolik.com", "foot.updated": "Mis à jour : %1",
  "action.refresh": "Actualiser",
  "detail.back": "‹ Matchs", "detail.events": "Faits de jeu", "detail.firstxi": "Compositions",
  "detail.officials": "Arbitres", "detail.notPlayed": "Le match n'a pas encore eu lieu",
  "ev.goal": "BUT", "ev.assist": "pas. déc. : %1", "ev.yc": "CARTON JAUNE", "ev.rc": "CARTON ROUGE",
  "ev.subIn": "Entrée : %1", "ev.subOut": "Sortie : %1",
  "onb.welcome": "Bienvenue dans Football", "onb.language": "Choisis ta langue",
  "onb.favorites": "Choisis tes équipes favorites", "onb.nt": "Choisis ta sélection",
  "onb.continue": "Continuer", "onb.skip": "Passer", "onb.save": "Enregistrer", "onb.search": "Chercher des équipes…",
  "onb.done": "C'est fait"
}
T["pt"] = {
  "panel.title": "Futebol",
  "tab.today": "Hoje", "tab.tomorrow": "Amanhã", "tab.results": "Resultados", "tab.table": "Classificação",
  "state.loading": "A carregar…", "state.emptyToday": "Sem jogos hoje", "state.emptyTomorrow": "Sem jogos marcados para amanhã",
  "state.emptyResults": "Sem resultados", "state.emptyTable": "Classificação indisponível",
  "state.error": "Não foi possível obter os dados — a mostrar o último estado conhecido",
  "match.ft": "FIM", "match.live": "AO VIVO",
  "col.team": "Equipa", "col.played": "J", "col.won": "V", "col.drawn": "E", "col.lost": "D",
  "col.gf": "GM", "col.ga": "GS", "col.gd": "Dif", "col.pts": "Pts", "col.form": "Forma",
  "table.season": "Época %1", "legend.champions": "Liga dos Campeões", "legend.europe": "Qualificação europeia",
  "legend.relegation": "Despromoção",
  "foot.source": "Fonte: mackolik.com", "foot.updated": "Atualizado: %1",
  "action.refresh": "Atualizar",
  "detail.back": "‹ Jogos", "detail.events": "Momentos", "detail.firstxi": "Onze inicial",
  "detail.officials": "Árbitros", "detail.notPlayed": "O jogo ainda não foi realizado",
  "ev.goal": "GOLO", "ev.assist": "assist.: %1", "ev.yc": "CARTÃO AMARELO", "ev.rc": "CARTÃO VERMELHO",
  "ev.subIn": "Entra: %1", "ev.subOut": "Sai: %1",
  "onb.welcome": "Bem-vindo ao Futebol", "onb.language": "Escolhe a tua língua",
  "onb.favorites": "Escolhe os teus clubes favoritos", "onb.nt": "Escolhe a tua seleção",
  "onb.continue": "Continuar", "onb.skip": "Ignorar", "onb.save": "Guardar", "onb.search": "Procurar clubes…",
  "onb.done": "Feito"
}
T["pt-BR"] = dict(T["pt"]); T["pt-BR"].update({"panel.title": "Futebol", "col.team": "Time", "tab.table": "Classificação", "match.ft": "FIM", "state.loading": "Carregando…", "onb.welcome": "Bem-vindo ao Futebol"})
T["nl"] = {
  "panel.title": "Voetbal",
  "tab.today": "Vandaag", "tab.tomorrow": "Morgen", "tab.results": "Uitslagen", "tab.table": "Stand",
  "state.loading": "Laden…", "state.emptyToday": "Geen wedstrijden vandaag", "state.emptyTomorrow": "Geen wedstrijden gepland voor morgen",
  "state.emptyResults": "Geen uitslagen gevonden", "state.emptyTable": "Stand niet beschikbaar",
  "state.error": "Kan gegevens niet ophalen — laatste bekende stand getoond",
  "match.ft": "EINDE", "match.live": "LIVE",
  "col.team": "Club", "col.played": "G", "col.won": "W", "col.drawn": "G", "col.lost": "V",
  "col.gf": "DV", "col.ga": "DT", "col.gd": "DS", "col.pts": "Ptn", "col.form": "Vorm",
  "table.season": "Seizoen %1", "legend.champions": "Champions League", "legend.europe": "Europees ticket",
  "legend.relegation": "Degradatie",
  "foot.source": "Bron: mackolik.com", "foot.updated": "Bijgewerkt: %1",
  "action.refresh": "Vernieuwen",
  "detail.back": "‹ Wedstrijden", "detail.events": "Wedstrijdverloop", "detail.firstxi": "Basisopstellingen",
  "detail.officials": "Scheidsrechters", "detail.notPlayed": "De wedstrijd is nog niet gespeeld",
  "ev.goal": "DOELPUNT", "ev.assist": "assist: %1", "ev.yc": "GELE KAART", "ev.rc": "RODE KAART",
  "ev.subIn": "In: %1", "ev.subOut": "Uit: %1",
  "onb.welcome": "Welkom bij Voetbal", "onb.language": "Kies je taal",
  "onb.favorites": "Kies je favoriete clubs", "onb.nt": "Kies je nationale elftal",
  "onb.continue": "Doorgaan", "onb.skip": "Overslaan", "onb.save": "Opslaan", "onb.search": "Clubs zoeken…",
  "onb.done": "Klaar"
}

T["pl"] = {
  "panel.title": "Piłka nożna",
  "tab.today": "Dziś", "tab.tomorrow": "Jutro", "tab.results": "Wyniki", "tab.table": "Tabela",
  "state.loading": "Ładowanie…", "state.emptyToday": "Brak meczów dzisiaj", "state.emptyTomorrow": "Brak meczów jutro",
  "state.emptyResults": "Brak wyników", "state.emptyTable": "Tabela niedostępna",
  "state.error": "Nie udało się pobrać danych — pokazano ostatni znany stan",
  "match.ft": "KONIEC", "match.live": "NA ŻYWO",
  "col.team": "Drużyna", "col.played": "M", "col.won": "W", "col.drawn": "R", "col.lost": "P",
  "col.gf": "BT", "col.ga": "BB", "col.gd": "+/-", "col.pts": "Pkt", "col.form": "Forma",
  "table.season": "Sezon %1", "legend.champions": "Liga Mistrzów", "legend.europe": "Kwalifikacje europejskie",
  "legend.relegation": "Spadek",
  "foot.source": "Źródło: mackolik.com", "foot.updated": "Zaktualizowano: %1",
  "action.refresh": "Odśwież",
  "detail.back": "‹ Mecze", "detail.events": "Przebieg meczu", "detail.firstxi": "Składy wyjściowe",
  "detail.officials": "Sędziowie", "detail.notPlayed": "Mecz jeszcze się nie odbył",
  "ev.goal": "GOL", "ev.assist": "asysta: %1", "ev.yc": "ŻÓŁTA KARTKA", "ev.rc": "CZERWONA KARTKA",
  "ev.subIn": "Wchodzi: %1", "ev.subOut": "Schodzi: %1",
  "onb.welcome": "Witaj w Piłce nożnej", "onb.language": "Wybierz język",
  "onb.favorites": "Wybierz ulubione kluby", "onb.nt": "Wybierz reprezentację",
  "onb.continue": "Dalej", "onb.skip": "Pomiń", "onb.save": "Zapisz", "onb.search": "Szukaj klubów…",
  "onb.done": "Gotowe"
}
T["cs"] = {
  "panel.title": "Fotbal",
  "tab.today": "Dnes", "tab.tomorrow": "Zítra", "tab.results": "Výsledky", "tab.table": "Tabulka",
  "state.loading": "Načítání…", "state.emptyToday": "Dnes žádné zápasy", "state.emptyTomorrow": "Zítra žádné zápasy",
  "state.emptyResults": "Žádné výsledky", "state.emptyTable": "Tabulka není k dispozici",
  "state.error": "Nepodařilo se načíst data — poslední známý stav",
  "match.ft": "KONEC", "match.live": "LIVE",
  "col.team": "Tým", "col.played": "Z", "col.won": "V", "col.drawn": "R", "col.lost": "P",
  "col.gf": "D+", "col.ga": "D−", "col.gd": "Roz", "col.pts": "B", "col.form": "Forma",
  "table.season": "Ročník %1", "legend.champions": "Liga mistrů", "legend.europe": "Evropská příčka",
  "legend.relegation": "Sestup",
  "foot.source": "Zdroj: mackolik.com", "foot.updated": "Aktualizováno: %1",
  "action.refresh": "Obnovit",
  "detail.back": "‹ Zápasy", "detail.events": "Průběh zápasu", "detail.firstxi": "Základní sestavy",
  "detail.officials": "Rozhodčí", "detail.notPlayed": "Zápas ještě nebyl odehrán",
  "ev.goal": "GÓL", "ev.assist": "asistence: %1", "ev.yc": "ŽLUTÁ KARTA", "ev.rc": "ČERVENÁ KARTA",
  "ev.subIn": "Přichází: %1", "ev.subOut": "Odchází: %1",
  "onb.welcome": "Vítej ve Fotbale", "onb.language": "Vyber jazyk",
  "onb.favorites": "Vyber oblíbené týmy", "onb.nt": "Vyber reprezentaci",
  "onb.continue": "Pokračovat", "onb.skip": "Přeskočit", "onb.save": "Uložit", "onb.search": "Hledat týmy…",
  "onb.done": "Hotovo"
}
T["sk"] = dict(T["cs"]); T["sk"].update({"state.emptyTomorrow": "Zajtra žiadne zápasy", "col.pts": "B", "table.season": "Ročník %1", "detail.firstxi": "Základné zostavy", "onb.welcome": "Vitaj vo Futbale"})
T["sl"] = dict(T["cs"]); T["sl"].update({"tab.today": "Danes", "tab.tomorrow": "Jutri", "tab.results": "Rezultati", "tab.table": "Lestvica", "state.emptyToday": "Danes ni tekem", "onb.welcome": "Dobrodošli v nogometu"})
T["hr"] = {
  "panel.title": "Nogomet",
  "tab.today": "Danas", "tab.tomorrow": "Sutra", "tab.results": "Rezultati", "tab.table": "Ljestvica",
  "state.loading": "Učitavanje…", "state.emptyToday": "Danas nema utakmica", "state.emptyTomorrow": "Sutra nema utakmica",
  "state.emptyResults": "Nema rezultata", "state.emptyTable": "Ljestvica nije dostupna",
  "state.error": "Podaci se ne mogu dohvatiti — prikazan je zadnji poznati status",
  "match.ft": "KRAJ", "match.live": "UŽIVO",
  "col.team": "Momčad", "col.played": "U", "col.won": "P", "col.drawn": "N", "col.lost": "I",
  "col.gf": "ZD", "col.ga": "PD", "col.gd": "+/-", "col.pts": "B", "col.form": "Forma",
  "table.season": "Sezona %1", "legend.champions": "Liga prvaka", "legend.europe": "Europska kvalifikacija",
  "legend.relegation": "Ispadanje",
  "foot.source": "Izvor: mackolik.com", "foot.updated": "Ažurirano: %1",
  "action.refresh": "Osvježi",
  "detail.back": "‹ Utakmice", "detail.events": "Događaji", "detail.firstxi": "Početne postave",
  "detail.officials": "Suci", "detail.notPlayed": "Utakmica još nije odigrana",
  "ev.goal": "GOL", "ev.assist": "asistencija: %1", "ev.yc": "ŽUTI KARTON", "ev.rc": "CRVENI KARTON",
  "ev.subIn": "Ulazi: %1", "ev.subOut": "Izlazi: %1",
  "onb.welcome": "Dobrodošao u Nogomet", "onb.language": "Odaberi jezik",
  "onb.favorites": "Odaberi omiljene klubove", "onb.nt": "Odaberi reprezentaciju",
  "onb.continue": "Dalje", "onb.skip": "Preskoči", "onb.save": "Spremi", "onb.search": "Pretraži klubove…",
  "onb.done": "Gotovo"
}
T["sr"] = dict(T["hr"]); T["sr"].update({"tab.table": "Табела", "onb.welcome": "Добродошао у фудбал"})
T["bg"] = {
  "panel.title": "Футбол",
  "tab.today": "Днес", "tab.tomorrow": "Утре", "tab.results": "Резултати", "tab.table": "Класиране",
  "state.loading": "Зареждане…", "state.emptyToday": "Днес няма мачове", "state.emptyTomorrow": "Утре няма насрочени мачове",
  "state.emptyResults": "Няма резултати", "state.emptyTable": "Класирането е недостъпно",
  "state.error": "Данните не могат да бъдат заредени — показва се последното известно състояние",
  "match.ft": "КРАЙ", "match.live": "НА ЖИВО",
  "col.team": "Отбор", "col.played": "И", "col.won": "В", "col.drawn": "Р", "col.lost": "З",
  "col.gf": "ВГ", "col.ga": "ДГ", "col.gd": "Р-ка", "col.pts": "Т", "col.form": "Форма",
  "table.season": "Сезон %1", "legend.champions": "Шампионска лига", "legend.europe": "Европейска квалификация",
  "legend.relegation": "Изпадане",
  "foot.source": "Източник: mackolik.com", "foot.updated": "Обновено: %1",
  "action.refresh": "Обнови",
  "detail.back": "‹ Мачове", "detail.events": "Събития", "detail.firstxi": "Стартови единайсеторки",
  "detail.officials": "Съдии", "detail.notPlayed": "Мачът още не е изигран",
  "ev.goal": "ГОЛ", "ev.assist": "асистенция: %1", "ev.yc": "ЖЪЛТ КАРТОН", "ev.rc": "ЧЕРВЕН КАРТОН",
  "ev.subIn": "Влиза: %1", "ev.subOut": "Излиза: %1",
  "onb.welcome": "Добре дошъл във Футбол", "onb.language": "Избери език",
  "onb.favorites": "Избери любими отбори", "onb.nt": "Избери национален отбор",
  "onb.continue": "Продължи", "onb.skip": "Пропусни", "onb.save": "Запази", "onb.search": "Търси отбори…",
  "onb.done": "Готово"
}
T["ro"] = {
  "panel.title": "Fotbal",
  "tab.today": "Azi", "tab.tomorrow": "Mâine", "tab.results": "Rezultate", "tab.table": "Clasament",
  "state.loading": "Se încarcă…", "state.emptyToday": "Nu există meciuri azi", "state.emptyTomorrow": "Nu există meciuri programate mâine",
  "state.emptyResults": "Nu există rezultate", "state.emptyTable": "Clasament indisponibil",
  "state.error": "Datele nu au putut fi încărcate — se arată ultima stare cunoscută",
  "match.ft": "FINAL", "match.live": "LIVE",
  "col.team": "Echipă", "col.played": "M", "col.won": "V", "col.drawn": "E", "col.lost": "Î",
  "col.gf": "GM", "col.ga": "GP", "col.gd": "DG", "col.pts": "Pct", "col.form": "Formă",
  "table.season": "Sezonul %1", "legend.champions": "Liga Campionilor", "legend.europe": "Calificare europeană",
  "legend.relegation": "Retrogradare",
  "foot.source": "Sursă: mackolik.com", "foot.updated": "Actualizat: %1",
  "action.refresh": "Reîmprospătează",
  "detail.back": "‹ Meciuri", "detail.events": "Evenimente", "detail.firstxi": "Echipe de start",
  "detail.officials": "Arbitri", "detail.notPlayed": "Meciul nu s-a jucat încă",
  "ev.goal": "GOL", "ev.assist": "pasă: %1", "ev.yc": "CARTON GALBEN", "ev.rc": "CARTON ROȘU",
  "ev.subIn": "Intră: %1", "ev.subOut": "Iese: %1",
  "onb.welcome": "Bine ai venit la Fotbal", "onb.language": "Alege limba",
  "onb.favorites": "Alege echipele favorite", "onb.nt": "Alege naționala",
  "onb.continue": "Continuă", "onb.skip": "Sari", "onb.save": "Salvează", "onb.search": "Caută echipe…",
  "onb.done": "Gata"
}
T["hu"] = {
  "panel.title": "Labdarúgás",
  "tab.today": "Ma", "tab.tomorrow": "Holnap", "tab.results": "Eredmények", "tab.table": "Tabella",
  "state.loading": "Betöltés…", "state.emptyToday": "Ma nincs mérkőzés", "state.emptyTomorrow": "Holnap nincs mérkőzés",
  "state.emptyResults": "Nincsenek eredmények", "state.emptyTable": "Tabella nem érhető el",
  "state.error": "Az adatok nem tölthetők be — az utolsó ismert állapot látható",
  "match.ft": "VÉGE", "match.live": "ÉLŐ",
  "col.team": "Csapat", "col.played": "M", "col.won": "Gy", "col.drawn": "D", "col.lost": "V",
  "col.gf": "GL", "col.ga": "GK", "col.gd": "GLK", "col.pts": "P", "col.form": "Forma",
  "table.season": "Szezon %1", "legend.champions": "Bajnokok Ligája", "legend.europe": "Európai továbbjutás",
  "legend.relegation": "Kiesés",
  "foot.source": "Forrás: mackolik.com", "foot.updated": "Frissítve: %1",
  "action.refresh": "Frissítés",
  "detail.back": "‹ Mérkőzések", "detail.events": "Események", "detail.firstxi": "Kezdőcsapatok",
  "detail.officials": "Játékvezetők", "detail.notPlayed": "A mérkőzés még nem játszották le",
  "ev.goal": "GÓL", "ev.assist": "gólpassz: %1", "ev.yc": "SÁRGA LAP", "ev.rc": "PIROS LAP",
  "ev.subIn": "Be: %1", "ev.subOut": "Ki: %1",
  "onb.welcome": "Üdv a Labdarúgásnál", "onb.language": "Nyelv kiválasztása",
  "onb.favorites": "Válaszd ki a kedvenc csapataidat", "onb.nt": "Válaszd ki a válogatottat",
  "onb.continue": "Tovább", "onb.skip": "Kihagy", "onb.save": "Mentés", "onb.search": "Csapatkeresés…",
  "onb.done": "Kész"
}
T["el"] = {
  "panel.title": "Ποδόσφαιρο",
  "tab.today": "Σήμερα", "tab.tomorrow": "Αύριο", "tab.results": "Αποτελέσματα", "tab.table": "Βαθμολογία",
  "state.loading": "Φόρτωση…", "state.emptyToday": "Δεν υπάρχουν αγώνες σήμερα", "state.emptyTomorrow": "Δεν υπάρχουν αγώνες αύριο",
  "state.emptyResults": "Δεν βρέθηκαν αποτελέσματα", "state.emptyTable": "Η βαθμολογία δεν είναι διαθέσιμη",
  "state.error": "Δεν ήταν δυνατή η φόρτωση — εμφάνιση τελευταίας γνωστής κατάστασης",
  "match.ft": "ΤΕΛΟΣ", "match.live": "ΖΩΝΤΑΝΆ",
  "col.team": "Ομάδα", "col.played": "Α", "col.won": "Ν", "col.drawn": "Ι", "col.lost": "Η",
  "col.gf": "Γ+", "col.ga": "Γ-", "col.gd": "Διαφ", "col.pts": "Β", "col.form": "Φόρμα",
  "table.season": "Σεζόν %1", "legend.champions": "Champions League", "legend.europe": "Ευρωπαϊκή πρόκριση",
  "legend.relegation": "Υποβιβασμός",
  "foot.source": "Πηγή: mackolik.com", "foot.updated": "Ενημερώθηκε: %1",
  "action.refresh": "Ανανέωση",
  "detail.back": "‹ Αγώνες", "detail.events": "Γεγονότα αγώνα", "detail.firstxi": "Βασικές ενδεκάδες",
  "detail.officials": "Διαιτητές", "detail.notPlayed": "Ο αγώνας δεν έχει διεξαχθεί ακόμη",
  "ev.goal": "ΓΚΟΛ", "ev.assist": "ασίστ: %1", "ev.yc": "ΚΙΤΡΙΝΗ ΚΑΡΤΑ", "ev.rc": "ΚΟΚΚΙΝΗ ΚΑΡΤΑ",
  "ev.subIn": "Μπαίνει: %1", "ev.subOut": "Βγαίνει: %1",
  "onb.welcome": "Καλώς ήρθες στο Ποδόσφαιρο", "onb.language": "Διάλεξε γλώσσα",
  "onb.favorites": "Διάλεξε τις αγαπημένες σου ομάδες", "onb.nt": "Διάλεξε την εθνική σου ομάδα",
  "onb.continue": "Συνέχεια", "onb.skip": "Παράλειψη", "onb.save": "Αποθήκευση", "onb.search": "Αναζήτηση ομάδων…",
  "onb.done": "Έτοιμο"
}

T["da"] = {
  "panel.title": "Fodbold",
  "tab.today": "I dag", "tab.tomorrow": "I morgen", "tab.results": "Resultater", "tab.table": "Stilling",
  "state.loading": "Indlæser…", "state.emptyToday": "Ingen kampe i dag", "state.emptyTomorrow": "Ingen kampe planlagt i morgen",
  "state.emptyResults": "Ingen resultater", "state.emptyTable": "Stilling ikke tilgængelig",
  "state.error": "Kunne ikke hente data — viser sidste kendte status",
  "match.ft": "SLUT", "match.live": "LIVE",
  "col.team": "Klub", "col.played": "K", "col.won": "V", "col.drawn": "U", "col.lost": "T",
  "col.gf": "MF", "col.ga": "MM", "col.gd": "Målf", "col.pts": "P", "col.form": "Form",
  "table.season": "Sæson %1", "legend.champions": "Champions League", "legend.europe": "Europæisk kvalifikation",
  "legend.relegation": "Nedrykning",
  "foot.source": "Kilde: mackolik.com", "foot.updated": "Opdateret: %1",
  "action.refresh": "Opdater",
  "detail.back": "‹ Kampe", "detail.events": "Kampens gang", "detail.firstxi": "Startopstillinger",
  "detail.officials": "Dommere", "detail.notPlayed": "Kampen er ikke spillet endnu",
  "ev.goal": "MÅL", "ev.assist": "assist: %1", "ev.yc": "GULT KORT", "ev.rc": "RØDT KORT",
  "ev.subIn": "Ind: %1", "ev.subOut": "Ud: %1",
  "onb.welcome": "Velkommen til Fodbold", "onb.language": "Vælg sprog",
  "onb.favorites": "Vælg dine yndlingsklubber", "onb.nt": "Vælg dit landshold",
  "onb.continue": "Fortsæt", "onb.skip": "Spring over", "onb.save": "Gem", "onb.search": "Søg klubber…",
  "onb.done": "Færdig"
}
T["sv"] = dict(T["da"]); T["sv"].update({"tab.today": "Idag", "tab.tomorrow": "Imorgon", "tab.results": "Resultat", "tab.table": "Tabell", "onb.welcome": "Välkommen till Fotboll", "state.emptyToday": "Inga matcher idag"})
T["no"] = dict(T["da"]); T["no"].update({"tab.today": "I dag", "tab.tomorrow": "I morgen", "onb.welcome": "Velkommen til Fotball", "panel.title": "Fotball"})
T["fi"] = {
  "panel.title": "Jalkapallo",
  "tab.today": "Tänään", "tab.tomorrow": "Huomenna", "tab.results": "Tulokset", "tab.table": "Sarjataulukko",
  "state.loading": "Ladataan…", "state.emptyToday": "Ei otteluita tänään", "state.emptyTomorrow": "Ei otteluita huomenna",
  "state.emptyResults": "Ei tuloksia", "state.emptyTable": "Sarjataulukko ei saatavilla",
  "state.error": "Tietoja ei voitu hakea — viimeisin tunnettu tila näytetään",
  "match.ft": "LOPPU", "match.live": "SUORA",
  "col.team": "Seura", "col.played": "O", "col.won": "V", "col.drawn": "T", "col.lost": "H",
  "col.gf": "MS", "col.ga": "MV", "col.gd": "ME", "col.pts": "P", "col.form": "Kunto",
  "table.season": "Kausi %1", "legend.champions": "Mestarien liiga", "legend.europe": "Eurooppalainen paikka",
  "legend.relegation": "Putoaminen",
  "foot.source": "Lähde: mackolik.com", "foot.updated": "Päivitetty: %1",
  "action.refresh": "Päivitä",
  "detail.back": "‹ Ottelut", "detail.events": "Tapahtumat", "detail.firstxi": "Aloituskokoonpanot",
  "detail.officials": "Tuomarit", "detail.notPlayed": "Ottelua ei ole vielä pelattu",
  "ev.goal": "MAALI", "ev.assist": "syöttö: %1", "ev.yc": "KELTAINEN KORTTI", "ev.rc": "PUNAINEN KORTTI",
  "ev.subIn": "Sisään: %1", "ev.subOut": "Ulos: %1",
  "onb.welcome": "Tervetuloa Jalkapalloon", "onb.language": "Valitse kieli",
  "onb.favorites": "Valitse lempijoukkueesi", "onb.nt": "Valitse maajoukkueesi",
  "onb.continue": "Jatka", "onb.skip": "Ohita", "onb.save": "Tallenna", "onb.search": "Hae joukkueita…",
  "onb.done": "Valmis"
}
T["is"] = dict(T["da"]); T["is"].update({"tab.today": "Í dag", "tab.tomorrow": "Á morgun", "tab.table": "Stigatafla", "onb.welcome": "Velkominn í Fótbolta", "panel.title": "Knattspyrna"})
T["ca"] = dict(T["es"]); T["ca"].update({"tab.today": "Avui", "tab.tomorrow": "Demà", "tab.table": "Classificació", "onb.welcome": "Benvingut al futbol"})
T["lt"] = {
  "panel.title": "Futbolas",
  "tab.today": "Šiandien", "tab.tomorrow": "Rytoj", "tab.results": "Rezultatai", "tab.table": "Lentelė",
  "state.loading": "Kraunama…", "state.emptyToday": "Šiandien rungtynių nėra", "state.emptyTomorrow": "Rytoj rungtynių nėra",
  "state.emptyResults": "Rezultatų nėra", "state.emptyTable": "Lentelė nepasiekiama",
  "state.error": "Nepavyko gauti duomenų — rodomas paskutinis žinomas būsena",
  "match.ft": "PABAIGA", "match.live": "TIESIOGIAI",
  "col.team": "Komanda", "col.played": "Ž", "col.won": "L", "col.drawn": "L", "col.lost": "P",
  "col.gf": "Į+", "col.ga": "Į−", "col.gd": "Skir", "col.pts": "Tš", "col.form": "Forma",
  "table.season": "Sezonas %1", "legend.champions": "Čempionų lyga", "legend.europe": "Europos vieta",
  "legend.relegation": "Iškritimas",
  "foot.source": "Šaltinis: mackolik.com", "foot.updated": "Atnaujinta: %1",
  "action.refresh": "Atnaujinti",
  "detail.back": "‹ Rungtynės", "detail.events": "Rungtynių eiga", "detail.firstxi": "Pradinės sudėtys",
  "detail.officials": "Teisėjai", "detail.notPlayed": "Rungtynės dar neįvyko",
  "ev.goal": "ĮVARTIS", "ev.assist": "rezultatyvus perdavimas: %1", "ev.yc": "GELTONA KORTELĖ", "ev.rc": "RAUDONA KORTELĖ",
  "ev.subIn": "Įeina: %1", "ev.subOut": "Išeina: %1",
  "onb.welcome": "Sveiki atvykę į Futbolą", "onb.language": "Pasirinkite kalbą",
  "onb.favorites": "Pasirinkite mėgstamiausias komandas", "onb.nt": "Pasirinkite nacionalinę rinktinę",
  "onb.continue": "Tęsti", "onb.skip": "Praleisti", "onb.save": "Išsaugoti", "onb.search": "Ieškoti komandų…",
  "onb.done": "Atlikta"
}
T["lv"] = dict(T["lt"]); T["lv"].update({"tab.today": "Šodien", "tab.table": "Tabula", "onb.welcome": "Laipni lūgti Futbolā", "panel.title": "Futbols"})
T["et"] = dict(T["lt"]); T["et"].update({"tab.today": "Täna", "tab.table": "Tabel", "panel.title": "Jalgpall", "onb.welcome": "Tere tulemast Jalgpalli"})
T["ga"] = dict(T["en"]); T["ga"].update({"panel.title": "Sacar", "tab.today": "Inniu", "onb.welcome": "Fáilte go Sacar"})
T["id"] = {
  "panel.title": "Sepak bola",
  "tab.today": "Hari ini", "tab.tomorrow": "Besok", "tab.results": "Hasil", "tab.table": "Klasemen",
  "state.loading": "Memuat…", "state.emptyToday": "Tidak ada pertandingan hari ini", "state.emptyTomorrow": "Tidak ada pertandingan besok",
  "state.emptyResults": "Tidak ada hasil", "state.emptyTable": "Klasemen tidak tersedia",
  "state.error": "Tidak dapat memuat data — menampilkan kondisi terakhir",
  "match.ft": "SELESAI", "match.live": "LANGSUNG",
  "col.team": "Klub", "col.played": "M", "col.won": "M", "col.drawn": "S", "col.lost": "K",
  "col.gf": "GM", "col.ga": "GK", "col.gd": "SM", "col.pts": "Poin", "col.form": "Form",
  "table.season": "Musim %1", "legend.champions": "Liga Champions", "legend.europe": "Tiket Eropa",
  "legend.relegation": "Degradasi",
  "foot.source": "Sumber: mackolik.com", "foot.updated": "Diperbarui: %1",
  "action.refresh": "Segarkan",
  "detail.back": "‹ Pertandingan", "detail.events": "Peristiwa", "detail.firstxi": "Susunan awal",
  "detail.officials": "Wasit", "detail.notPlayed": "Pertandingan belum dimainkan",
  "ev.goal": "GOL", "ev.assist": "umpan: %1", "ev.yc": "KARTU KUNING", "ev.rc": "KARTU MERAH",
  "ev.subIn": "Masuk: %1", "ev.subOut": "Keluar: %1",
  "onb.welcome": "Selamat datang di Sepak bola", "onb.language": "Pilih bahasa",
  "onb.favorites": "Pilih klub favoritmu", "onb.nt": "Pilih tim nasionalmu",
  "onb.continue": "Lanjut", "onb.skip": "Lewati", "onb.save": "Simpan", "onb.search": "Cari klub…",
  "onb.done": "Selesai"
}
T["ms"] = dict(T["id"]); T["ms"].update({"panel.title": "Bola sepak", "tab.results": "Keputusan", "tab.table": "Kedudukan", "onb.welcome": "Selamat datang ke Bola sepak"})
T["fil"] = dict(T["id"]); T["fil"].update({"panel.title": "Soccer", "tab.today": "Ngayon", "tab.tomorrow": "Bukas", "tab.results": "Resulta", "tab.table": "Tabla", "onb.welcome": "Maligayang pagdating sa Futbol"})

T["uk"] = {
  "panel.title": "Футбол",
  "tab.today": "Сьогодні", "tab.tomorrow": "Завтра", "tab.results": "Результати", "tab.table": "Таблиця",
  "state.loading": "Завантаження…", "state.emptyToday": "Сьогодні матчів немає", "state.emptyTomorrow": "Завтра матчів немає",
  "state.emptyResults": "Немає результатів", "state.emptyTable": "Таблиця недоступна",
  "state.error": "Не вдалося завантажити дані — показано останній відомий стан",
  "match.ft": "КІНЕЦЬ", "match.live": "НАЖИВО",
  "col.team": "Команда", "col.played": "І", "col.won": "В", "col.drawn": "Н", "col.lost": "П",
  "col.gf": "ЗГ", "col.ga": "ПГ", "col.gd": "Р.", "col.pts": "О", "col.form": "Форма",
  "table.season": "Сезон %1", "legend.champions": "Ліга чемпіонів", "legend.europe": "Європейська кваліфікація",
  "legend.relegation": "Виліт",
  "foot.source": "Джерело: mackolik.com", "foot.updated": "Оновлено: %1",
  "action.refresh": "Оновити",
  "detail.back": "‹ Матчі", "detail.events": "Події", "detail.firstxi": "Стартові склади",
  "detail.officials": "Судді", "detail.notPlayed": "Матч ще не відбувся",
  "ev.goal": "ГОЛ", "ev.assist": "асист: %1", "ev.yc": "ЖОВТА КАРТКА", "ev.rc": "ЧЕРВОНА КАРТКА",
  "ev.subIn": "Вихід: %1", "ev.subOut": "Вихід з поля: %1",
  "onb.welcome": "Ласкаво просимо до Футболу", "onb.language": "Виберіть мову",
  "onb.favorites": "Виберіть улюблені команди", "onb.nt": "Виберіть збірну",
  "onb.continue": "Продовжити", "onb.skip": "Пропустити", "onb.save": "Зберегти", "onb.search": "Пошук команд…",
  "onb.done": "Готово"
}
T["ru"] = dict(T["uk"]); T["ru"].update({"tab.today": "Сегодня", "tab.tomorrow": "Завтра", "tab.results": "Результаты", "tab.table": "Таблица", "state.emptyToday": "Сегодня матчей нет", "state.loading": "Загрузка…", "onb.welcome": "Добро пожаловать в Футбол", "onb.done": "Готово"})
T["ar"] = {
  "panel.title": "كرة القدم",
  "tab.today": "اليوم", "tab.tomorrow": "غداً", "tab.results": "النتائج", "tab.table": "الترتيب",
  "state.loading": "جارٍ التحميل…", "state.emptyToday": "لا توجد مباريات اليوم", "state.emptyTomorrow": "لا توجد مباريات غداً",
  "state.emptyResults": "لا توجد نتائج", "state.emptyTable": "الترتيب غير متاح",
  "state.error": "تعذر تحميل البيانات — تظهر آخر حالة معروفة",
  "match.ft": "انتهاء", "match.live": "مباشر",
  "col.team": "الفريق", "col.played": "لعب", "col.won": "فوز", "col.drawn": "تعادل", "col.lost": "خسارة",
  "col.gf": "له", "col.ga": "عليه", "col.gd": "فارق", "col.pts": "نقاط", "col.form": "الفورمة",
  "table.season": "الموسم %1", "legend.champions": "دوري أبطال أوروبا", "legend.europe": "التأهل الأوروبي",
  "legend.relegation": "الهبوط",
  "foot.source": "المصدر: mackolik.com", "foot.updated": "آخر تحديث: %1",
  "action.refresh": "تحديث",
  "detail.back": "‹ المباريات", "detail.events": "أحداث المباراة", "detail.firstxi": "التشكيلة الأساسية",
  "detail.officials": "الحكام", "detail.notPlayed": "لم تُلعب المباراة بعد",
  "ev.goal": "هدف", "ev.assist": "تمريرة: %1", "ev.yc": "بطاقة صفراء", "ev.rc": "بطاقة حمراء",
  "ev.subIn": "دخول: %1", "ev.subOut": "خروج: %1",
  "onb.welcome": "أهلاً بك في كرة القدم", "onb.language": "اختر لغتك",
  "onb.favorites": "اختر أنديتك المفضلة", "onb.nt": "اختر منتخب بلادك",
  "onb.continue": "متابعة", "onb.skip": "تخطي", "onb.save": "حفظ", "onb.search": "ابحث عن أندية…",
  "onb.done": "تم"
}
T["fa"] = dict(T["ar"]); T["fa"].update({"panel.title": "فوتبال", "tab.today": "امروز", "tab.tomorrow": "فردا", "tab.results": "نتایج", "tab.table": "جدول", "onb.welcome": "به فوتبال خوش آمدید", "detail.officials": "داوران"})
T["he"] = dict(T["ar"]); T["he"].update({"panel.title": "כדורגל", "tab.today": "היום", "tab.tomorrow": "מחר", "tab.results": "תוצאות", "tab.table": "טבלה", "onb.welcome": "ברוך הבא לכדורגל", "onb.done": "סיום"})
T["hi"] = {
  "panel.title": "फ़ुटबॉल",
  "tab.today": "आज", "tab.tomorrow": "कल", "tab.results": "नतीजे", "tab.table": "तालिका",
  "state.loading": "लोड हो रहा है…", "state.emptyToday": "आज कोई मैच नहीं", "state.emptyTomorrow": "कल कोई मैच नहीं",
  "state.emptyResults": "कोई नतीजा नहीं", "state.emptyTable": "तालिका उपलब्ध नहीं",
  "state.error": "डेटा लोड नहीं हो सका — अंतिम ज्ञात स्थिति दिख रही है",
  "match.ft": "समाप्त", "match.live": "लाइव",
  "col.team": "टीम", "col.played": "खे", "col.won": "जीत", "col.drawn": "ड्रॉ", "col.lost": "हार",
  "col.gf": "गें", "col.ga": "वि", "col.gd": "अं", "col.pts": "अंक", "col.form": "फ़ॉर्म",
  "table.season": "सीज़न %1", "legend.champions": "चैंपियंस लीग", "legend.europe": "यूरोपीय योग्यता",
  "legend.relegation": "पदावनति",
  "foot.source": "स्रोत: mackolik.com", "foot.updated": "अपडेट: %1",
  "action.refresh": "रीफ़्रेश",
  "detail.back": "‹ मैच", "detail.events": "इवेंट्स", "detail.firstxi": "शुरुआती 11",
  "detail.officials": "रेफ़री", "detail.notPlayed": "मैच अभी नहीं खेला गया",
  "ev.goal": "गोल", "ev.assist": "असिस्ट: %1", "ev.yc": "पीली कार्ड", "ev.rc": "लाल कार्ड",
  "ev.subIn": "अंदर: %1", "ev.subOut": "बाहर: %1",
  "onb.welcome": "फ़ुटबॉल में आपका स्वागत है", "onb.language": "अपनी भाषा चुनें",
  "onb.favorites": "अपनी पसंदीदा टीमें चुनें", "onb.nt": "अपना राष्ट्रीय दल चुनें",
  "onb.continue": "जारी रखें", "onb.skip": "छोड़ें", "onb.save": "सहेजें", "onb.search": "टीमें खोजें…",
  "onb.done": "हो गया"
}
T["bn"] = dict(T["hi"]); T["bn"].update({"panel.title": "ফুটবল", "tab.today": "আজ", "tab.tomorrow": "কাল", "tab.table": "তালিকা", "onb.welcome": "ফুটবলে স্বাগতম", "detail.firstxi": "প্রাথমিক লাইনআপ"})
T["si"] = dict(T["hi"]); T["si"].update({"panel.title": "පාපන්දු", "tab.today": "අද", "tab.tomorrow": "හෙට", "tab.table": "වගුව", "onb.welcome": "පාපන්දුවට සාදරයෙන් පිළිගනිමු"})
T["ta"] = dict(T["hi"]); T["ta"].update({"panel.title": "கால்பந்து", "tab.today": "இன்று", "tab.tomorrow": "நாளை", "tab.table": "அட்டவணை", "onb.welcome": "கால்பந்திற்கு வரவேற்கிறோம்"})
T["th"] = {
  "panel.title": "ฟุตบอล",
  "tab.today": "วันนี้", "tab.tomorrow": "พรุ่งนี้", "tab.results": "ผลการแข่งขัน", "tab.table": "ตารางคะแนน",
  "state.loading": "กำลังโหลด…", "state.emptyToday": "ไม่มีการแข่งขันวันนี้", "state.emptyTomorrow": "ไม่มีการแข่งขันพรุ่งนี้",
  "state.emptyResults": "ไม่พบผลการแข่งขัน", "state.emptyTable": "ไม่สามารถดูตารางคะแนนได้",
  "state.error": "ไม่สามารถโหลดข้อมูล — แสดงสถานะล่าสุดที่รู้",
  "match.ft": "จบ", "match.live": "LIVE",
  "col.team": "ทีม", "col.played": "แข่ง", "col.won": "ชนะ", "col.drawn": "เสมอ", "col.lost": "แพ้",
  "col.gf": "ยิง", "col.ga": "เสีย", "col.gd": "+/-", "col.pts": "แต้ม", "col.form": "ฟอร์ม",
  "table.season": "ฤดูกาล %1", "legend.champions": "ยูฟ่า แชมเปียนส์ลีก", "legend.europe": "โควตาไปยุโรป",
  "legend.relegation": "ตกชั้น",
  "foot.source": "ที่มา: mackolik.com", "foot.updated": "อัปเดต: %1",
  "action.refresh": "รีเฟรช",
  "detail.back": "‹ การแข่งขัน", "detail.events": "เหตุการณ์ในเกม", "detail.firstxi": "รายชื่อผู้เล่นตัวจริง",
  "detail.officials": "ผู้ตัดสิน", "detail.notPlayed": "ยังไม่ได้แข่ง",
  "ev.goal": "ประตู", "ev.assist": "แอสซิสต์: %1", "ev.yc": "ใบเหลือง", "ev.rc": "ใบแดง",
  "ev.subIn": "เข้าเกม: %1", "ev.subOut": "ออกจากเกม: %1",
  "onb.welcome": "ยินดีต้อนรับสู่ฟุตบอล", "onb.language": "เลือกภาษา",
  "onb.favorites": "เลือกทีมโปรดของคุณ", "onb.nt": "เลือกทีมชาติของคุณ",
  "onb.continue": "ดำเนินการต่อ", "onb.skip": "ข้าม", "onb.save": "บันทึก", "onb.search": "ค้นหาทีม…",
  "onb.done": "เสร็จสิ้น"
}
T["sw"] = dict(T["en"]); T["sw"].update({"panel.title": "Mpira wa miguu", "tab.today": "Leo", "tab.tomorrow": "Kesho", "tab.table": "Jedwali", "onb.welcome": "Karibu kwenye Mpira wa miguu"})
T["vi"] = {
  "panel.title": "Bóng đá",
  "tab.today": "Hôm nay", "tab.tomorrow": "Ngày mai", "tab.results": "Kết quả", "tab.table": "Bảng xếp hạng",
  "state.loading": "Đang tải…", "state.emptyToday": "Hôm nay không có trận đấu", "state.emptyTomorrow": "Ngày mai không có trận đấu",
  "state.emptyResults": "Không có kết quả", "state.emptyTable": "Bảng xếp hạng không khả dụng",
  "state.error": "Không thể tải dữ liệu — hiển thị trạng thái gần nhất",
  "match.ft": "KẾT THÚC", "match.live": "TRỰC TIẾP",
  "col.team": "Đội", "col.played": "Tr", "col.won": "T", "col.drawn": "H", "col.lost": "B",
  "col.gf": "BT", "col.ga": "BB", "col.gd": "HS", "col.pts": "Đ", "col.form": "Phong độ",
  "table.season": "Mùa giải %1", "legend.champions": "Cúp C1", "legend.europe": "Vé dự cúp châu Âu",
  "legend.relegation": "Xuống hạng",
  "foot.source": "Nguồn: mackolik.com", "foot.updated": "Cập nhật: %1",
  "action.refresh": "Làm mới",
  "detail.back": "‹ Các trận", "detail.events": "Diễn biến trận đấu", "detail.firstxi": "Đội hình xuất phát",
  "detail.officials": "Trọng tài", "detail.notPlayed": "Trận đấu chưa diễn ra",
  "ev.goal": "BÀN THẮNG", "ev.assist": "kiến tạo: %1", "ev.yc": "THẺ VÀNG", "ev.rc": "THẺ ĐỎ",
  "ev.subIn": "Vào sân: %1", "ev.subOut": "Ra sân: %1",
  "onb.welcome": "Chào mừng đến với Bóng đá", "onb.language": "Chọn ngôn ngữ",
  "onb.favorites": "Chọn các đội yêu thích", "onb.nt": "Chọn đội tuyển quốc gia",
  "onb.continue": "Tiếp tục", "onb.skip": "Bỏ qua", "onb.save": "Lưu", "onb.search": "Tìm đội bóng…",
  "onb.done": "Xong"
}
T["ja"] = {
  "panel.title": "サッカー",
  "tab.today": "今日", "tab.tomorrow": "明日", "tab.results": "結果", "tab.table": "順位表",
  "state.loading": "読み込み中…", "state.emptyToday": "本日の試合はありません", "state.emptyTomorrow": "明日の試合はありません",
  "state.emptyResults": "結果はありません", "state.emptyTable": "順位表を取得できません",
  "state.error": "データを取得できません — 前回の状態を表示",
  "match.ft": "終了", "match.live": "ライブ",
  "col.team": "クラブ", "col.played": "試", "col.won": "勝", "col.drawn": "分", "col.lost": "負",
  "col.gf": "得", "col.ga": "失", "col.gd": "差", "col.pts": "勝点", "col.form": "勝敗",
  "table.season": "%1 シーズン", "legend.champions": "チャンピオンズリーグ", "legend.europe": "欧州出場権",
  "legend.relegation": "降格",
  "foot.source": "ソース: mackolik.com", "foot.updated": "更新: %1",
  "action.refresh": "更新",
  "detail.back": "‹ 試合", "detail.events": "試合の経過", "detail.firstxi": "スタメン",
  "detail.officials": "審判", "detail.notPlayed": "試合はまだ行われていません",
  "ev.goal": "ゴール", "ev.assist": "アシスト: %1", "ev.yc": "イエローカード", "ev.rc": "レッドカード",
  "ev.subIn": "交代 IN: %1", "ev.subOut": "交代 OUT: %1",
  "onb.welcome": "サッカーへようこそ", "onb.language": "言語を選択",
  "onb.favorites": "お気に入りのクラブを選択", "onb.nt": "代表を選択",
  "onb.continue": "続ける", "onb.skip": "スキップ", "onb.save": "保存", "onb.search": "クラブを検索…",
  "onb.done": "完了"
}
T["ko"] = {
  "panel.title": "축구",
  "tab.today": "오늘", "tab.tomorrow": "내일", "tab.results": "결과", "tab.table": "순위",
  "state.loading": "불러오는 중…", "state.emptyToday": "오늘 경기 없음", "state.emptyTomorrow": "내일 경기 없음",
  "state.emptyResults": "결과 없음", "state.emptyTable": "순위를 불러올 수 없음",
  "state.error": "데이터를 불러올 수 없음 — 마지막 상태 표시",
  "match.ft": "종료", "match.live": "LIVE",
  "col.team": "클럽", "col.played": "경", "col.won": "승", "col.drawn": "무", "col.lost": "패",
  "col.gf": "득", "col.ga": "실", "col.gd": "득실", "col.pts": "승점", "col.form": "전적",
  "table.season": "%1 시즌", "legend.champions": "챔피언스리그", "legend.europe": "유럽 대회 진출권",
  "legend.relegation": "강등",
  "foot.source": "출처: mackolik.com", "foot.updated": "업데이트: %1",
  "action.refresh": "새로고침",
  "detail.back": "‹ 경기", "detail.events": "경기 진행", "detail.firstxi": "스타팅 라인업",
  "detail.officials": "심판", "detail.notPlayed": "경기가 아직 열리지 않았습니다",
  "ev.goal": "골", "ev.assist": "도움: %1", "ev.yc": "옐로카드", "ev.rc": "레드카드",
  "ev.subIn": "교체 IN: %1", "ev.subOut": "교체 OUT: %1",
  "onb.welcome": "축구에 오신 것을 환영합니다", "onb.language": "언어 선택",
  "onb.favorites": "즐겨찾는 클럽 선택", "onb.nt": "국가대표팀 선택",
  "onb.continue": "계속", "onb.skip": "건너뛰기", "onb.save": "저장", "onb.search": "클럽 검색…",
  "onb.done": "완료"
}
T["zh-CN"] = {
  "panel.title": "足球",
  "tab.today": "今天", "tab.tomorrow": "明天", "tab.results": "赛果", "tab.table": "积分榜",
  "state.loading": "加载中…", "state.emptyToday": "今天没有比赛", "state.emptyTomorrow": "明天没有比赛",
  "state.emptyResults": "暂无赛果", "state.emptyTable": "积分榜不可用",
  "state.error": "无法加载数据 — 显示最近一次的状态",
  "match.ft": "完", "match.live": "直播",
  "col.team": "球队", "col.played": "场", "col.won": "胜", "col.drawn": "平", "col.lost": "负",
  "col.gf": "进", "col.ga": "失", "col.gd": "净", "col.pts": "分", "col.form": "状态",
  "table.season": "%1 赛季", "legend.champions": "欧冠", "legend.europe": "欧洲席位",
  "legend.relegation": "降级",
  "foot.source": "数据来源: mackolik.com", "foot.updated": "更新于 %1",
  "action.refresh": "刷新",
  "detail.back": "‹ 比赛", "detail.events": "比赛动态", "detail.firstxi": "首发阵容",
  "detail.officials": "裁判", "detail.notPlayed": "比赛尚未进行",
  "ev.goal": "进球", "ev.assist": "助攻: %1", "ev.yc": "黄牌", "ev.rc": "红牌",
  "ev.subIn": "换人 IN: %1", "ev.subOut": "换人 OUT: %1",
  "onb.welcome": "欢迎来到足球", "onb.language": "选择语言",
  "onb.favorites": "选择你喜欢的俱乐部", "onb.nt": "选择你的国家队",
  "onb.continue": "继续", "onb.skip": "跳过", "onb.save": "保存", "onb.search": "搜索俱乐部…",
  "onb.done": "完成"
}
T["zh-TW"] = dict(T["zh-CN"]); T["zh-TW"].update({"tab.today": "今天", "tab.tomorrow": "明天", "state.loading": "載入中…", "onb.welcome": "歡迎來到足球"})
T["ur"] = dict(T["ar"]); T["ur"].update({"panel.title": "فٹ بال", "tab.today": "آج", "tab.tomorrow": "کل", "tab.table": "جدول", "onb.welcome": "فٹ بال میں خوش آمدید"})
T["uz"] = dict(T["uk"]); T["uz"].update({"panel.title": "Futbol", "tab.today": "Bugun", "tab.tomorrow": "Ertaga", "tab.table": "Jadval", "onb.welcome": "Futbolga xush kelibsiz"})

import os
base = os.path.dirname(os.path.abspath(__file__)) + "/../i18n"
os.makedirs(base, exist_ok=True)
missing_langs = []
for code in CODES:
    table = dict(T.get("en", {}))
    table.update(T.get(code, {}))
    with open(os.path.join(base, code + ".json"), "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=2)
    if code not in T:
        missing_langs.append(code)
print("wrote", len(CODES), "locales")
print("fallback-to-english:", missing_langs if missing_langs else "none")
