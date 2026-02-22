#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$ROOT_DIR/documents"
INDEX_FILE="$ROOT_DIR/index.html"

usage() {
  cat <<'EOF'
Gebruik:
  scripts/add_document.sh <pad/naar/bestand.pdf> [opties]

Opties:
  --title "Titel"      Titel in index en HTML (standaard: afgeleid van bestandsnaam)
  --date "dd mmm yyyy" Datum voor index en HTML (standaard: CreationDate uit PDF, anders vandaag)
  --slug "bestandsnaam" Doelbestandsnaam zonder extensie (ASCII; standaard: afgeleid van bestandsnaam)
  --move               Verplaats bron-PDF naar documents/ in plaats van kopieren
  --no-index           Voeg geen rij toe aan index.html
  --ocr                Forceer OCR met tesseract (ook als pdftotext al tekst vindt)
  -h, --help           Toon hulp

Voorbeeld:
  scripts/add_document.sh "/tmp/Voorlopig verslag.pdf" \
    --title "Voorlopig deskundig verslag (Ref FMO 202411N002)" \
    --date "23 jan 2026"
EOF
}

slugify() {
  local input="$1"
  local ascii

  if command -v iconv >/dev/null 2>&1; then
    ascii="$(printf '%s' "$input" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$input")"
  else
    ascii="$input"
  fi

  ascii="$(printf '%s' "$ascii" | tr '[:upper:]' '[:lower:]')"
  ascii="$(printf '%s' "$ascii" | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g')"

  if [[ -z "$ascii" ]]; then
    ascii="document_$(date +%s)"
  fi

  printf '%s\n' "$ascii"
}

pretty_title() {
  local base="$1"
  base="${base//_/ }"
  base="${base//-/ }"
  printf '%s\n' "$(printf '%s' "$base" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
}

html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

nl_date_from_iso() {
  local iso="$1"
  local dd mm yyyy mon

  dd="$(date -d "$iso" +%d)"
  mm="$(date -d "$iso" +%m)"
  yyyy="$(date -d "$iso" +%Y)"

  case "$mm" in
    01) mon="jan" ;;
    02) mon="feb" ;;
    03) mon="mrt" ;;
    04) mon="apr" ;;
    05) mon="mei" ;;
    06) mon="jun" ;;
    07) mon="jul" ;;
    08) mon="aug" ;;
    09) mon="sep" ;;
    10) mon="okt" ;;
    11) mon="nov" ;;
    12) mon="dec" ;;
    *) mon="" ;;
  esac

  printf '%s %s %s\n' "$dd" "$mon" "$yyyy"
}

guess_date() {
  local pdf_file="$1"
  local creation iso

  creation="$(pdfinfo "$pdf_file" 2>/dev/null | awk -F': *' '/^CreationDate:/{print $2; exit}')"
  if [[ -n "$creation" ]]; then
    iso="$(date -d "$creation" +%Y-%m-%d 2>/dev/null || true)"
    if [[ -n "$iso" ]]; then
      nl_date_from_iso "$iso"
      return 0
    fi
  fi

  nl_date_from_iso "$(date +%Y-%m-%d)"
}

SOURCE_PDF=""
DOC_TITLE=""
DOC_DATE=""
DOC_SLUG=""
MOVE_SOURCE=0
UPDATE_INDEX=1
FORCE_OCR=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      DOC_TITLE="${2:-}"
      shift 2
      ;;
    --date)
      DOC_DATE="${2:-}"
      shift 2
      ;;
    --slug)
      DOC_SLUG="${2:-}"
      shift 2
      ;;
    --move)
      MOVE_SOURCE=1
      shift
      ;;
    --no-index)
      UPDATE_INDEX=0
      shift
      ;;
    --ocr)
      FORCE_OCR=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Onbekende optie: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$SOURCE_PDF" ]]; then
        SOURCE_PDF="$1"
      else
        echo "Meerdere bronbestanden opgegeven, verwacht exact 1 PDF." >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$SOURCE_PDF" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$SOURCE_PDF" ]]; then
  echo "Bestand niet gevonden: $SOURCE_PDF" >&2
  exit 1
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "pdftotext is niet beschikbaar." >&2
  exit 1
fi

mkdir -p "$DOCS_DIR"

SOURCE_ABS="$(cd "$(dirname "$SOURCE_PDF")" && pwd)/$(basename "$SOURCE_PDF")"
SOURCE_BASE="$(basename "$SOURCE_ABS")"
SOURCE_STEM="${SOURCE_BASE%.*}"
SOURCE_EXT="${SOURCE_BASE##*.}"

if [[ "${SOURCE_EXT,,}" != "pdf" ]]; then
  echo "Alleen PDF-bestanden worden ondersteund: $SOURCE_PDF" >&2
  exit 1
fi

if [[ -z "$DOC_SLUG" ]]; then
  DOC_SLUG="$(slugify "$SOURCE_STEM")"
else
  DOC_SLUG="$(slugify "$DOC_SLUG")"
fi

if [[ -z "$DOC_TITLE" ]]; then
  DOC_TITLE="$(pretty_title "$SOURCE_STEM")"
fi

TARGET_PDF="$DOCS_DIR/$DOC_SLUG.pdf"
TARGET_HTML="$DOCS_DIR/$DOC_SLUG.html"

if [[ "$SOURCE_ABS" != "$TARGET_PDF" ]]; then
  if [[ "$MOVE_SOURCE" -eq 1 ]]; then
    mv "$SOURCE_ABS" "$TARGET_PDF"
  else
    cp "$SOURCE_ABS" "$TARGET_PDF"
  fi
fi

if [[ -z "$DOC_DATE" ]]; then
  DOC_DATE="$(guess_date "$TARGET_PDF")"
fi

TMP_TXT="$(mktemp)"
TMP_PAR="$(mktemp)"
TMP_HTML="$(mktemp)"
TMP_OCR_DIR=""
trap 'rm -f "$TMP_TXT" "$TMP_PAR" "$TMP_HTML"; if [[ -n "$TMP_OCR_DIR" ]]; then rm -rf "$TMP_OCR_DIR"; fi' EXIT

pdftotext "$TARGET_PDF" - | tr '\f' '\n' > "$TMP_TXT"

TEXT_NONSPACE="$(tr -d '[:space:]' < "$TMP_TXT" | wc -c | tr -d ' ')"
NEEDS_OCR=0
if [[ "$FORCE_OCR" -eq 1 ]]; then
  NEEDS_OCR=1
elif [[ "$TEXT_NONSPACE" -lt 200 ]]; then
  NEEDS_OCR=1
fi

if [[ "$NEEDS_OCR" -eq 1 && -x "$(command -v tesseract || true)" && -x "$(command -v pdftoppm || true)" ]]; then
  TMP_OCR_DIR="$(mktemp -d)"
  pdftoppm -png -r 300 "$TARGET_PDF" "$TMP_OCR_DIR/page" >/dev/null 2>&1

  : > "$TMP_TXT"
  for img in "$TMP_OCR_DIR"/page-*.png; do
    [[ -e "$img" ]] || continue
    tesseract "$img" stdout -l nld+eng --psm 6 2>/dev/null >> "$TMP_TXT" || true
    printf '\n\n' >> "$TMP_TXT"
  done
fi

awk 'BEGIN{RS=""; ORS="\n"} {
  gsub(/\r/, "", $0)
  gsub(/\f/, " ", $0)
  gsub(/[ \t]*\n[ \t]*/, " ", $0)
  gsub(/[ \t]+/, " ", $0)
  sub(/^ /, "", $0)
  sub(/ $/, "", $0)
  if ($0 ~ /^[0-9]+$/) next
  if (length($0) == 0) next
  print $0
}' "$TMP_TXT" > "$TMP_PAR"

DOC_TITLE_HTML="$(html_escape "$DOC_TITLE")"
DOC_DATE_HTML="$(html_escape "$DOC_DATE")"

{
  cat <<HTML_TOP
<!doctype html>
<html lang="nl">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Document - $DOC_TITLE_HTML</title>
    <link rel="stylesheet" href="../styles/common.css" />
    <link rel="stylesheet" href="../styles/mail.css" />
  </head>
  <body>
    <main class="wrap">
      <section class="card">
        <header class="header">
          <div class="page-links">
            <a class="page-link" href="../index.html">Portaal</a>
            <a class="page-link" href="$DOC_SLUG.pdf">PDF</a>
          </div>
          <h1 class="title">Document: $DOC_TITLE_HTML</h1>
          <p class="subtitle">HTML-opmaak op basis van <code>documents/$DOC_SLUG.pdf</code></p>
        </header>

        <dl class="mail-meta">
          <div class="mail-row">
            <dt>Type</dt>
            <dd>PDF-document</dd>
          </div>
          <div class="mail-row">
            <dt>Datum</dt>
            <dd>$DOC_DATE_HTML</dd>
          </div>
          <div class="mail-row">
            <dt>Titel</dt>
            <dd>$DOC_TITLE_HTML</dd>
          </div>
          <div class="mail-row">
            <dt>Bron</dt>
            <dd><a href="$DOC_SLUG.pdf">documents/$DOC_SLUG.pdf</a></dd>
          </div>
        </dl>

        <article class="mail-body">
HTML_TOP

  while IFS= read -r line; do
    line_escaped="$(html_escape "$line")"
    printf '          <p>%s</p>\n' "$line_escaped"
  done < "$TMP_PAR"

  cat <<'HTML_BOTTOM'
        </article>
      </section>
    </main>
  </body>
</html>
HTML_BOTTOM
} > "$TMP_HTML"

mv "$TMP_HTML" "$TARGET_HTML"
chmod 664 "$TARGET_HTML"

if [[ "$UPDATE_INDEX" -eq 1 ]]; then
  if grep -Fq "documents/$DOC_SLUG.html" "$INDEX_FILE"; then
    echo "Index bevat al een rij voor documents/$DOC_SLUG.html; geen extra rij toegevoegd."
  else
    TMP_INDEX="$(mktemp)"
    trap 'rm -f "$TMP_TXT" "$TMP_PAR" "$TMP_HTML" "$TMP_INDEX"' EXIT

    awk \
      -v doc_date="$DOC_DATE_HTML" \
      -v doc_title="$DOC_TITLE_HTML" \
      -v doc_slug="$DOC_SLUG" \
      'BEGIN{in_docs=0; inserted=0}
      {
        if ($0 ~ /<section class="catalog-block" aria-labelledby="documenten-heading">/) in_docs=1

        if (in_docs && $0 ~ /<\/tbody>/ && !inserted) {
          print "                  <tr>"
          print "                    <td>" doc_date "</td>"
          print "                    <td>" doc_title "</td>"
          print "                    <td>"
          print "                      <a class=\"document-html-link\" href=\"documents/" doc_slug ".html\">html</a>"
          print "                      <span aria-hidden=\"true\"> | </span>"
          print "                      <a href=\"documents/" doc_slug ".pdf\">pdf</a>"
          print "                    </td>"
          print "                  </tr>"
          inserted=1
        }

        print

        if (in_docs && $0 ~ /<\/section>/) in_docs=0
      }
      END{
        if (!inserted) exit 3
      }' "$INDEX_FILE" > "$TMP_INDEX" || {
        echo "Kon documenten-rij niet invoegen in index.html (sectie 'documenten' niet gevonden)." >&2
        exit 1
      }

    mv "$TMP_INDEX" "$INDEX_FILE"
  fi
fi

echo "Klaar."
echo "PDF : documents/$DOC_SLUG.pdf"
echo "HTML: documents/$DOC_SLUG.html"
if [[ "$UPDATE_INDEX" -eq 1 ]]; then
  echo "Index: index.html bijgewerkt (of bestaand item behouden)."
else
  echo "Index: niet aangepast (--no-index)."
fi
