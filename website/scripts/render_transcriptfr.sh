#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PATH="${1:-$ROOT_DIR/../transcriptfr.org}"
OUTPUT_PATH="${2:-$ROOT_DIR/transcript_meeting_imelda_rossenbacker.html}"

if [[ ! -f "$SOURCE_PATH" ]]; then
  echo "Bronbestand niet gevonden: $SOURCE_PATH" >&2
  exit 1
fi

perl - "$SOURCE_PATH" "$OUTPUT_PATH" <<'PL'
use strict;
use warnings;

my ($input_path, $output_path) = @ARGV;

sub escape_html {
  my ($text) = @_;
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  return $text;
}

sub markup_to_html {
  my ($text) = @_;
  my $escaped = escape_html($text);

  $escaped =~ s{==(.+?)==}{'<span class="note">' . $1 . '</span>'}ge;
  $escaped =~ s{\[(.+?)\]}{'<span class="rossenbacker">' . $1 . '</span>'}ge;
  $escaped =~ s{\{(.+?)\}}{'<span class="peter">' . $1 . '</span>'}ge;
  $escaped =~ s{\|(.+?)\|}{'<span class="simon">' . $1 . '</span>'}ge;
  $escaped =~ s{~(.+?)~}{'<span class="greet">' . $1 . '</span>'}ge;
  $escaped =~ s{--(.+?)--}{'<span class="anke">' . $1 . '</span>'}ge;

  # Fallback for lines where source markers are not closed.
  $escaped =~ s{(^|\s)\[([^\]]+)$}{$1 . '<span class="rossenbacker">' . $2 . '</span>'}ge;
  $escaped =~ s{(^|\s)\{([^\}]+)$}{$1 . '<span class="peter">' . $2 . '</span>'}ge;
  $escaped =~ s{(^|\s)\|([^\|]+)$}{$1 . '<span class="simon">' . $2 . '</span>'}ge;
  $escaped =~ s{(^|\s)~([^~]+)$}{$1 . '<span class="greet">' . $2 . '</span>'}ge;
  $escaped =~ s{(^|\s)--(.+)$}{$1 . '<span class="anke">' . $2 . '</span>'}ge;

  $escaped =~ s{(\s*(?:,\.\.\.|\.{3}|…)+\s*)}{'<span class="unclear">' . $1 . '</span>'}ge;
  return $escaped;
}

open my $in, '<:encoding(UTF-8)', $input_path or die "Cannot read $input_path: $!\n";
my @rows;
my $current_timestamp;
my $current_body = '';

sub flush_current_row {
  my ($rows_ref, $timestamp_ref, $body_ref) = @_;
  return if !defined $$timestamp_ref;

  my $body = $$body_ref // '';
  $body =~ s/^\s+//;
  $body =~ s/\s+$//;
  if ($body ne '') {
    push @{$rows_ref}, {
      timestamp => $$timestamp_ref,
      body_html => markup_to_html($body),
    };
  }

  $$timestamp_ref = undef;
  $$body_ref = '';
}

while (my $line = <$in>) {
  chomp $line;
  $line =~ s/\r$//;
  next if $line =~ /^\s*$/;

  if ($line =~ /^\s*(\d{1,2}:\d{2})(?::)?\s*(.*)$/) {
    flush_current_row(\@rows, \$current_timestamp, \$current_body);
    $current_timestamp = $1;
    $current_body = $2 // '';
    next;
  }

  next if !defined $current_timestamp;
  my $continuation = $line;
  $continuation =~ s/^\s+//;
  $continuation =~ s/\s+$//;
  next if $continuation eq '';

  if ($current_body eq '') {
    $current_body = $continuation;
  } else {
    $current_body .= " $continuation";
  }
}

flush_current_row(\@rows, \$current_timestamp, \$current_body);
close $in;
open my $out, '>:encoding(UTF-8)', $output_path or die "Cannot write $output_path: $!\n";

print {$out} <<'HTML_HEAD';
<!doctype html>
<html lang="nl">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Transcript - Gesprek Imelda</title>
    <link rel="stylesheet" href="styles/common.css" />
    <link rel="stylesheet" href="styles/transcript.css" />
  </head>
  <body>
    <main class="wrap">
      <section class="card">
        <header class="header">
          <div class="page-links">
            <a class="page-link" href="index.html">Portaal</a>
          </div>
          <h1 class="title">Transcript Gesprek Imelda</h1>
          <ul class="legend" aria-label="Legenda transcript">
            <li class="legend-item"><span class="legend-chip rossenbacker">Dr. Rossenbacker</span></li>
            <li class="legend-item"><span class="legend-chip peter">Peter</span></li>
            <li class="legend-item"><span class="legend-chip anke">Anke</span></li>
            <li class="legend-item"><span class="legend-chip simon">Simon</span></li>
            <li class="legend-item"><span class="legend-chip greet">Greet</span></li>
            <li class="legend-item"><span class="legend-chip note">Opmerking</span></li>
            <li class="legend-item">
              <span class="legend-unclear"><span class="legend-unclear-icon" aria-hidden="true">[?]</span>Onduidelijk</span>
            </li>
          </ul>
        </header>
        <div class="audio-panel">
          <p class="audio-label">Audio-opname</p>
          <audio id="call-audio" class="audio-player" controls preload="metadata">
            <source src="meeting_imelda_rossenbacker.mp3" type="audio/mpeg" />
            Je browser ondersteunt het audio-element niet.
          </audio>
          <p class="audio-hint">Klik op een tijdstempel om te starten. Klik elders op het scherm om te pauzeren of te hervatten vanaf hetzelfde punt.</p>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Tijd</th>
                <th>Gesprek</th>
              </tr>
            </thead>
            <tbody>
HTML_HEAD

for my $row (@rows) {
  print {$out} "              <tr>\n";
  print {$out} "                <td class=\"timestamp\">$row->{timestamp}</td>\n";
  print {$out} "                <td class=\"line\">$row->{body_html}</td>\n";
  print {$out} "              </tr>\n";
}

print {$out} <<'HTML_TAIL';
            </tbody>
          </table>
        </div>
      </section>
    </main>
    <script>
      (function () {
        const audio = document.getElementById("call-audio");
        if (!audio) return;
        const audioPanel = document.querySelector(".audio-panel");
        const card = audioPanel ? audioPanel.closest(".card") : null;
        const audioPanelSpacer = document.createElement("div");
        if (audioPanel && card) {
          audioPanelSpacer.className = "audio-panel-spacer";
          audioPanel.insertAdjacentElement("afterend", audioPanelSpacer);
        }

        let floatingPanelRaf = null;
        const syncFloatingAudioPanel = () => {
          if (!audioPanel || !card) return;

          const panelHeight = audioPanel.offsetHeight || 0;
          const cardRect = card.getBoundingClientRect();
          const shouldFloat = cardRect.top < 0 && cardRect.bottom > panelHeight + 12;

          if (!shouldFloat) {
            audioPanel.classList.remove("is-floating");
            audioPanelSpacer.classList.remove("is-active");
            audioPanelSpacer.style.height = "";
            audioPanel.style.left = "";
            audioPanel.style.width = "";
            return;
          }

          const left = Math.max(cardRect.left, 0);
          const maxWidth = Math.max(window.innerWidth - left, 0);
          audioPanel.classList.add("is-floating");
          audioPanelSpacer.classList.add("is-active");
          audioPanelSpacer.style.height = panelHeight + "px";
          audioPanel.style.left = left + "px";
          audioPanel.style.width = Math.min(cardRect.width, maxWidth) + "px";
        };

        const scheduleFloatingAudioPanelSync = () => {
          if (floatingPanelRaf !== null) return;
          floatingPanelRaf = window.requestAnimationFrame(() => {
            floatingPanelRaf = null;
            syncFloatingAudioPanel();
          });
        };

        if (audioPanel && card) {
          window.addEventListener("scroll", scheduleFloatingAudioPanelSync, { passive: true });
          window.addEventListener("resize", scheduleFloatingAudioPanelSync);
          scheduleFloatingAudioPanelSync();
        }

        const parseTimestamp = (label) => {
          const parts = label.trim().split(":").map(Number);
          if (parts.some(Number.isNaN)) return null;
          if (parts.length === 2) {
            return (parts[0] * 60) + parts[1];
          }
          if (parts.length === 3) {
            return (parts[0] * 3600) + (parts[1] * 60) + parts[2];
          }
          return null;
        };

        const formatTimestamp = (totalSeconds) => {
          const minutes = Math.floor(totalSeconds / 60);
          const seconds = Math.floor(totalSeconds % 60);
          return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        };

        const jumpTo = (seconds) => {
          audio.currentTime = seconds;
          audio.play().catch(function () {});
        };

        const speakerLabelEntries = [
          ["rossenbacker", "Dr. Rossenbacker"],
          ["peter", "Peter"],
          ["valerie", "Valerie Discart"],
          ["anke", "Anke"],
          ["simon", "Simon"],
          ["greet", "Greet"],
          ["note", "Opmerking"]
        ];

        document.querySelectorAll("td.line span").forEach((segment) => {
          for (const [className, label] of speakerLabelEntries) {
            if (!segment.classList.contains(className)) continue;
            segment.setAttribute("title", "Spreker: " + label);
            segment.setAttribute("aria-label", "Spreker: " + label);
            break;
          }
        });

        const timestampRows = [];
        document.querySelectorAll("tbody tr").forEach((row) => {
          const cell = row.querySelector("td.timestamp");
          if (!cell) return;

          const rawLabel = cell.textContent.trim();
          const seconds = parseTimestamp(rawLabel);
          if (seconds === null) return;
          const label = formatTimestamp(seconds);
          cell.textContent = label;

          cell.classList.add("is-seekable");
          cell.setAttribute("role", "button");
          cell.setAttribute("tabindex", "0");
          cell.setAttribute("title", "Start audio op " + label);
          cell.setAttribute("aria-label", "Start audio op " + label);

          cell.addEventListener("click", () => jumpTo(seconds));
          cell.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              jumpTo(seconds);
            }
          });

          timestampRows.push({
            row,
            seconds,
            index: timestampRows.length
          });
        });

        let activeRow = null;

        const setActiveRow = (nextRow) => {
          if (activeRow === nextRow) return;
          if (activeRow) activeRow.classList.remove("is-active");
          activeRow = nextRow;
          if (activeRow) activeRow.classList.add("is-active");
        };

        const findActiveRow = (currentSeconds) => {
          let candidate = null;

          for (const item of timestampRows) {
            if (item.seconds > currentSeconds) continue;
            if (
              !candidate ||
              item.seconds > candidate.seconds ||
              (item.seconds === candidate.seconds && item.index > candidate.index)
            ) {
              candidate = item;
            }
          }

          return candidate ? candidate.row : null;
        };

        const syncTranscriptWithAudio = () => {
          if (!timestampRows.length) return;
          const nextRow = findActiveRow(audio.currentTime || 0);
          if (!audio.paused) {
            setActiveRow(nextRow);
          } else {
            setActiveRow(null);
          }
        };

        audio.addEventListener("timeupdate", syncTranscriptWithAudio);
        audio.addEventListener("play", syncTranscriptWithAudio);
        audio.addEventListener("seeked", syncTranscriptWithAudio);
        audio.addEventListener("pause", () => setActiveRow(null));
        audio.addEventListener("ended", () => setActiveRow(null));

        document.addEventListener("click", (event) => {
          if (event.target.closest("td.timestamp.is-seekable")) return;
          if (event.target.closest("#call-audio")) return;
          if (audio.paused) {
            audio.play().catch(function () {});
            return;
          }
          audio.pause();
        });
      })();
    </script>
  </body>
</html>
HTML_TAIL

close $out;
PL

echo "Gegenereerd: $OUTPUT_PATH"
