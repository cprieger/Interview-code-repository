document.addEventListener("DOMContentLoaded", () => {
  const pollButton = document.getElementById("poll-button");
  if (!pollButton) return;

  const referenceInput = document.getElementById("reference_system");
  const statusEl = document.getElementById("status");
  const tbody = document.querySelector("#deals-table tbody");

  pollButton.addEventListener("click", async () => {
    const referenceSystem = referenceInput.value.trim();
    if (!referenceSystem) {
      statusEl.textContent = "Enter a reference system name.";
      return;
    }

    pollButton.disabled = true;
    statusEl.textContent = "Polling contracts... this can take a moment.";
    tbody.innerHTML = "";

    try {
      const resp = await fetch("/api/poll", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reference_system: referenceSystem }),
      });
      const data = await resp.json();

      if (!resp.ok) {
        statusEl.textContent = `Error: ${data.error || resp.statusText}`;
        return;
      }

      renderDeals(data.deals);
      statusEl.textContent = `Found ${data.deals.length} deal(s).`;
    } catch (err) {
      statusEl.textContent = `Request failed: ${err}`;
    } finally {
      pollButton.disabled = false;
    }
  });

  function renderDeals(deals) {
    tbody.innerHTML = "";
    for (const deal of deals) {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${escapeHtml(deal.system_name)}</td>
        <td>${escapeHtml(deal.title)}</td>
        <td>${formatIsk(deal.price)}</td>
        <td>${formatIsk(deal.fair_value)}</td>
        <td>${deal.discount_pct}%</td>
        <td>${escapeHtml(deal.item_summary)}</td>
      `;
      tbody.appendChild(row);
    }
  }

  function formatIsk(value) {
    return Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 });
  }

  function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str ?? "";
    return div.innerHTML;
  }
});
