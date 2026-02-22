# AGENTS.md

## Scope
Deze instructies gelden voor de volledige map `/home/peter/Documents/keerbergen/mama/dossier/website`.

## Vaste workflow voor nieuwe mails
- Bronbestanden staan in `mails/` als `.txt`.
- Voor elke nieuwe mail-tekst maak je een HTML-versie in dezelfde map met dezelfde basisnaam (bijv. `mails/voorbeeld.txt` -> `mails/voorbeeld.html`).
- Gebruik voor elke mailpagina dezelfde layout als de bestaande mails:
  - stylesheet links: `../styles/common.css` en `../styles/mail.css`
  - navigatielink bovenaan naar `../index.html` (alleen `Portaal`)
  - metadata-blok met `Van`, `Datum`, `Onderwerp`, `Aan`
  - opgemaakte tekst in leesbare paragrafen
- Gebruik geen backupbestanden zoals `*~` als bron.

## Vaste workflow voor nieuwe documenten (PDF)
- Bronbestanden staan in `documents/` als `.pdf`.
- Gebruik bij voorkeur het script `scripts/add_document.sh` om documenten toe te voegen:
  - standaard: `scripts/add_document.sh /pad/naar/document.pdf`
  - voor gescande PDF's (afbeeldingen i.p.v. tekst): `scripts/add_document.sh /pad/naar/scan.pdf --ocr`
- Het script:
  - maakt/normaliseert `documents/<slug>.pdf`
  - maakt `documents/<slug>.html` met dezelfde site-layout
  - voegt automatisch een rij toe in de `documenten`-sectie van `index.html` met links `html | pdf`
- OCR gebruikt `tesseract` (talen `nld+eng`) via het script.

## Portaal (`index.html`)
- Hou de sectie `zoeken` met zoekveld (form naar `search.html` met queryparameter `q`).
- Hou de sectie `mails` als tabel met kolommen `Datum` en `Mail`.
- Plaats onder de titel `mails` altijd deze vaste noot: `NOOT : alle samenvattingen door AI, klik op mail lijn voor volledige mail`.
- Voeg bij elke nieuwe mail een nieuwe rij toe met:
  - kolom 1: datum uit de mailheader
  - kolom 2: link naar de nieuwe HTML-mail
- Gebruik in de datumkolom altijd hetzelfde formaat: `dd mmm yyyy` (bijv. `08 nov 2023`).
- Plaats naast elke maillink een openklapbare knop `Samenvatting` met een korte samenvatting van 3 tot 6 zinnen.
- Uitzondering: bij `Mail mieke bbq` (`mails/mail0.html`) staat geen samenvattingsknop.
- Hou de sectie `documenten` tussen `mails` en `transcript`.
  - `documenten` is een tabel met kolommen `Datum`, `Document`, `Links`.
  - in `Links` staat telkens `html | pdf` (met de HTML-link als doorzoekbare bron).
- Laat de sectie `transcript` bestaan en behoud de bestaande link(s).
- Behoud de bestaande look-and-feel via `styles/common.css` en `styles/index.css`.

## Zoekfunctie
- Zoekpagina staat in `search.html`, met styles `styles/search.css` en script `scripts/search.js`.
- Zoekindex wordt in JavaScript opgebouwd op basis van links die al in `index.html` staan (mails + documenten + transcript). Daardoor worden nieuwe items automatisch doorzocht zodra ze in het portaal staan.

## Naamgeving
- Houd bestandsnamen ASCII en zoveel mogelijk in lijn met bestaande naamgeving.
