(function () {
  const form = document.getElementById("search-form");
  const queryInput = document.getElementById("query");
  const status = document.getElementById("search-status");
  const resultsContainer = document.getElementById("search-results");

  if (!form || !queryInput || !status || !resultsContainer) {
    return;
  }

  const state = {
    docs: [],
    ready: false,
  };

  const toQuery = () => new URLSearchParams(window.location.search);

  const normalize = (text) => text.toLowerCase();

  const escapeHtml = (text) =>
    text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");

  const escapeRegExp = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const dedupeByUrl = (items) => {
    const seen = new Set();
    return items.filter((item) => {
      if (!item.url || seen.has(item.url)) return false;
      seen.add(item.url);
      return true;
    });
  };

  const countOccurrences = (haystack, needle) => {
    if (!needle) return 0;
    let count = 0;
    let offset = 0;
    while (true) {
      const pos = haystack.indexOf(needle, offset);
      if (pos === -1) break;
      count += 1;
      offset = pos + needle.length;
    }
    return count;
  };

  const extractText = (html) => {
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, "text/html");
    doc.querySelectorAll("script, style, noscript").forEach((node) => node.remove());

    const scope = doc.querySelector("main") || doc.body;
    return (scope ? scope.textContent : "").replace(/\s+/g, " ").trim();
  };

  const fetchPortalTargets = async () => {
    const response = await fetch("index.html");
    if (!response.ok) {
      throw new Error("Kon index.html niet laden voor documentlijst.");
    }

    const html = await response.text();
    const parser = new DOMParser();
    const portal = parser.parseFromString(html, "text/html");

    const docs = [];

    const mailSection = portal.querySelector('[aria-labelledby="mails-heading"]');
    if (mailSection) {
      mailSection.querySelectorAll(".mail-table tbody tr").forEach((row) => {
        const cells = row.querySelectorAll("td");
        const date = cells[0] ? cells[0].textContent.trim() : "";
        const link = row.querySelector("a[href]");
        if (!link) return;
        docs.push({
          title: link.textContent.trim(),
          url: link.getAttribute("href"),
          type: "mail",
          date,
        });
      });
    }

    const documentsSection = portal.querySelector('[aria-labelledby="documenten-heading"]');
    if (documentsSection) {
      documentsSection.querySelectorAll(".mail-table tbody tr").forEach((row) => {
        const cells = row.querySelectorAll("td");
        const date = cells[0] ? cells[0].textContent.trim() : "";
        const title = cells[1] ? cells[1].textContent.trim() : "";
        const link = row.querySelector("a.document-html-link[href], a[href$='.html'], a[href]");
        if (!link) return;
        docs.push({
          title: title || link.textContent.trim(),
          url: link.getAttribute("href"),
          type: "document",
          date,
        });
      });
    }

    const transcriptSection = portal.querySelector(
      '[aria-labelledby="transcripts-heading"], [aria-labelledby="transcript-heading"]'
    );
    if (transcriptSection) {
      const transcriptRows = transcriptSection.querySelectorAll(".mail-table tbody tr");
      if (transcriptRows.length) {
        transcriptRows.forEach((row) => {
          const cells = row.querySelectorAll("td");
          const date = cells[0] ? cells[0].textContent.trim() : "";
          const link = row.querySelector("a[href]");
          if (!link) return;
          docs.push({
            title: link.textContent.trim(),
            url: link.getAttribute("href"),
            type: "transcript",
            date,
          });
        });
      } else {
        transcriptSection.querySelectorAll("a[href]").forEach((link) => {
          docs.push({
            title: link.textContent.trim(),
            url: link.getAttribute("href"),
            type: "transcript",
            date: "",
          });
        });
      }
    }

    return dedupeByUrl(docs);
  };

  const buildIndex = async () => {
    status.textContent = "Indexeren van documenten...";

    const targets = await fetchPortalTargets();
    const loaded = await Promise.all(
      targets.map(async (target) => {
        try {
          const response = await fetch(target.url);
          if (!response.ok) return null;

          const html = await response.text();
          const text = extractText(html);
          if (!text) return null;

          return {
            ...target,
            text,
            normalizedText: normalize(text),
          };
        } catch (_error) {
          return null;
        }
      })
    );

    state.docs = loaded.filter(Boolean);
    state.ready = true;

    status.textContent = "Index klaar. Zoek op trefwoord.";
  };

  const makeSnippet = (doc, terms) => {
    let firstHit = -1;
    terms.forEach((term) => {
      const pos = doc.normalizedText.indexOf(term);
      if (pos !== -1 && (firstHit === -1 || pos < firstHit)) {
        firstHit = pos;
      }
    });

    if (firstHit === -1) {
      firstHit = 0;
    }

    const start = Math.max(0, firstHit - 90);
    const end = Math.min(doc.text.length, firstHit + 210);
    let snippet = doc.text.slice(start, end).trim();

    if (start > 0) snippet = "..." + snippet;
    if (end < doc.text.length) snippet += "...";

    let safe = escapeHtml(snippet);
    terms.forEach((term) => {
      const re = new RegExp("(" + escapeRegExp(term) + ")", "gi");
      safe = safe.replace(re, "<mark>$1</mark>");
    });

    return safe;
  };

  const renderResults = (query, results) => {
    if (!query.trim()) {
      resultsContainer.innerHTML = "";
      status.textContent = "Typ een zoekterm en druk op Zoek.";
      return;
    }

    if (!results.length) {
      resultsContainer.innerHTML = "";
      status.textContent = "Geen resultaten gevonden.";
      return;
    }

    status.textContent = results.length + " resultaat/resultaten gevonden.";

    resultsContainer.innerHTML = results
      .map((result) => {
        const dateChip = result.date
          ? '<span class="search-chip">' + escapeHtml(result.date) + "</span>"
          : "";

        return (
          '<li class="search-result-item">' +
          '<a class="search-result-link" href="' + escapeHtml(result.url) + '">' +
          escapeHtml(result.title) +
          "</a>" +
          '<div class="search-result-meta">' +
          '<span class="search-chip">' +
          escapeHtml(result.type) +
          "</span>" +
          dateChip +
          "</div>" +
          '<p class="search-result-snippet">' +
          makeSnippet(result, result._terms) +
          "</p>" +
          "</li>"
        );
      })
      .join("");
  };

  const search = (rawQuery) => {
    if (!state.ready) return;

    const query = rawQuery.trim();
    const terms = normalize(query)
      .split(/\s+/)
      .map((term) => term.trim())
      .filter(Boolean);

    if (!terms.length) {
      renderResults(query, []);
      return;
    }

    const results = state.docs
      .map((doc) => {
        const hasAllTerms = terms.every((term) => doc.normalizedText.includes(term));
        if (!hasAllTerms) return null;

        const score = terms.reduce(
          (sum, term) => sum + countOccurrences(doc.normalizedText, term),
          0
        );

        return {
          ...doc,
          _terms: terms,
          _score: score,
        };
      })
      .filter(Boolean)
      .sort((a, b) => b._score - a._score || a.title.localeCompare(b.title));

    renderResults(query, results);
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();

    const query = queryInput.value;
    const params = new URLSearchParams(window.location.search);
    if (query.trim()) {
      params.set("q", query.trim());
    } else {
      params.delete("q");
    }

    const next = window.location.pathname + (params.toString() ? "?" + params.toString() : "");
    window.history.replaceState({}, "", next);

    search(query);
  });

  (async function init() {
    const initialQuery = toQuery().get("q") || "";
    queryInput.value = initialQuery;

    try {
      await buildIndex();
      if (initialQuery.trim()) {
        search(initialQuery);
      } else {
        status.textContent = "Index klaar. Typ een zoekterm en druk op Zoek.";
      }
    } catch (error) {
      status.textContent = "Zoeken kon niet opstarten: " + (error && error.message ? error.message : "onbekende fout");
    }
  })();
})();
