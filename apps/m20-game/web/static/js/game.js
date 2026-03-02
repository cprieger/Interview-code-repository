/* M20 Game — Client-side logic
 * Depends on jQuery 3.7.1 (served locally — no CDN).
 * All state is in-memory + localStorage for the character ID.
 */

(function ($) {
  'use strict';

  // ── State ────────────────────────────────────────────────────────────
  const state = {
    character: null,
    inventory: [],
    map: null,
  };

  const API = {
    tile:      '/api/tile',
    land:      '/api/land',
    scavenge:  '/api/scavenge',
    items:     '/api/items',
    craft:     '/api/craft',
    combat:    '/api/combat/roll',
    riddle:    '/api/ai/riddle',
    character: '/api/character',
  };

  // ── Init ─────────────────────────────────────────────────────────────
  $(function () {
    loadClasses();
    restoreSession();

    $('#char-class').on('change', previewClass);
    $('#create-btn').on('click', createCharacter);
    $('#generate-map-btn').on('click', generateMap);
    $('#scavenge-btn').on('click', doScavenge);
    $('#explore-btn').on('click', doExploreBuilding);
    $('#combat-btn').on('click', doCombat);
    $('#riddle-btn').on('click', doRiddle);
    $('#craft-btn').on('click', doCraft);
  });

  // ── Session restore ───────────────────────────────────────────────────
  function restoreSession() {
    const id = localStorage.getItem('m20_char_id');
    if (!id) return;
    get(`${API.character}/${id}/sheet`)
      .done(function (data) {
        state.character = data.character;
        state.inventory = data.character.inventory || [];
        showGame();
        log(`Welcome back, ${state.character.name}.`, 'success');
      })
      .fail(function () {
        localStorage.removeItem('m20_char_id');
      });
  }

  // ── Character creation ────────────────────────────────────────────────
  function loadClasses() {
    get(API.items).done(function (data) {
      $.each(data.classes, function (_, cls) {
        $('#char-class').append($('<option>').val(cls.name).text(cls.name));
      });
    });
  }

  function previewClass() {
    const chosen = $('#char-class').val();
    if (!chosen) { $('#class-info').addClass('hidden'); return; }
    get(API.items).done(function (data) {
      const cls = data.classes.find(c => c.name === chosen);
      if (!cls) return;
      const bonuses = Object.entries(cls.bonus_stats)
        .map(([k, v]) => `${k} +${v}`)
        .join(', ');
      $('#class-info').html(
        `<div class="flavor">"${cls.flavor}"</div>` +
        `<strong>Special:</strong> ${cls.special_ability}<br>` +
        `<strong>Bonuses:</strong> ${bonuses}`
      ).removeClass('hidden');
    });
  }

  function createCharacter() {
    const name = $('#char-name').val().trim();
    if (!name) { showError('Enter a survivor name.'); return; }

    post(API.character, {
      name: name,
      class: $('#char-class').val() || '',
    }).done(function (c) {
      state.character = c;
      state.inventory = c.inventory || [];
      localStorage.setItem('m20_char_id', c.id);
      showGame();
      log(`${c.name} the ${c.class} enters the dungeon. HP: ${c.hp}/${c.max_hp}`, 'success');
      generateMap();
    });
  }

  // ── Show game UI ──────────────────────────────────────────────────────
  function showGame() {
    $('#create-section').addClass('hidden');
    $('#game-section').removeClass('hidden');
    renderStats();
    renderInventory();
  }

  function renderStats() {
    const c = state.character;
    if (!c) return;

    $('#char-name-display').text(c.name);
    $('#char-class-display').text(`[${c.class}]`);
    $('#hp-display').text(`HP ${c.hp}/${c.max_hp}`);

    const stats = c.stats;
    const labels = {
      strength: 'STR', stamina: 'STA', marksmanship: 'MRK',
      scouting: 'SCT', scavenging: 'SCG', crafting: 'CRF', salvaging: 'SLV',
    };
    let html = '';
    $.each(labels, function (key, label) {
      html += `<div class="stat-item">
        <span class="stat-label">${label}</span>
        <span class="stat-value">${stats[key]}</span>
      </div>`;
    });
    html += `<div class="stat-item">
      <span class="stat-label">LVL</span>
      <span class="stat-value">${c.level}</span>
    </div>
    <div class="stat-item">
      <span class="stat-label">XP</span>
      <span class="stat-value">${c.xp}</span>
    </div>`;
    $('#stats-bar').html(html);
  }

  function renderInventory() {
    const max = state.character.class === 'Hoarder' ? 8 : 5;
    $('#inv-count').text(`(${state.inventory.length}/${max})`);
    if (state.inventory.length === 0) {
      $('#inventory-list').html('<span style="color:var(--muted);font-size:12px">Nothing yet.</span>');
    } else {
      $('#inventory-list').html(state.inventory.map(i => `<span class="inv-item">${i}</span>`).join(''));
    }
  }

  // ── Map ───────────────────────────────────────────────────────────────
  function generateMap() {
    post(API.land, { tileCount: 9 }).done(function (data) {
      state.map = data;
      renderMap();
      log('New map generated. 9 tiles. Watch your step.', 'warning');
    });
  }

  const TILE_ICONS = {
    'Ruined City Block':    '🏚',
    'Overgrown Highway':    '🛣',
    'Abandoned Suburb':     '🏠',
    'Gas Station':          '⛽',
    'Hospital':             '🏥',
    'Underground Parking':  '🅿',
    'Forest Edge':          '🌲',
    'Military Outpost':     '🪖',
    'Shopping Mall':        '🏬',
    'Dungeon Entrance':     '⚠️',
  };

  function renderMap() {
    if (!state.map) return;
    let html = '';
    $.each(state.map.tiles, function (_, tile) {
      const icon = TILE_ICONS[tile.type.name] || '❓';
      html += `<div class="map-tile danger-${tile.type.danger}${tile.explored ? ' explored' : ''}"
                    data-tile-id="${tile.id}">
        <span class="tile-icon">${icon}</span>
        <span class="tile-name">${tile.id}</span>
      </div>`;
    });
    $('#map-grid').html(html);
  }

  // ── Scavenge ──────────────────────────────────────────────────────────
  function doScavenge() {
    const level = state.character ? state.character.stats.scouting : 3;
    get(`${API.scavenge}?level=${level}`).done(function (data) {
      log(`Scavenge (scout ${level}): ${data.description}`);
      const max = state.character.class === 'Hoarder' ? 8 : 5;
      $.each(data.found, function (_, item) {
        if (state.inventory.length < max) {
          state.inventory.push(item.name);
          log(`  → Found: ${item.name}`, 'success');
        } else {
          log(`  → Inventory full. Left behind: ${item.name}`, 'warning');
        }
      });
      renderInventory();
    });
  }

  // ── Building ──────────────────────────────────────────────────────────
  function doExploreBuilding() {
    get('/api/tile').done(function (tile) {
      log(`You enter: ${tile.type.name}. ${tile.type.description}`);
      if (tile.encounter_type === 'building') {
        log('You find a building to explore.', 'warning');
      }
      if (tile.encounter_type === 'monster') {
        log('You hear something move.', 'combat');
      }
    });
  }

  // ── Combat ────────────────────────────────────────────────────────────
  function doCombat() {
    const stat = state.character ? state.character.stats.strength : 3;
    post(API.combat, { stat: stat, bonus: 0 }).done(function (data) {
      const msg = `Combat roll — d20: ${data.roll}, total: ${data.total} → ${data.outcome.toUpperCase()}`;
      log(msg, data.outcome.includes('success') ? 'success' : 'combat');
      if (data.outcome === 'crit_success') {
        log('Critical hit! The monster reels.', 'success');
      } else if (data.outcome === 'crit_failure') {
        log('You stumble. The monster sees its chance.', 'combat');
      }
    });
  }

  // ── Riddle (Ollama AI) ────────────────────────────────────────────────
  function doRiddle() {
    log('The Sphinx regards you with ancient patience…', 'ai');
    $('#riddle-btn').prop('disabled', true).text('Asking the Sphinx…');
    get(API.riddle)
      .done(function (data) {
        log(`SPHINX: "${data.riddle}"`, 'ai');
        if (data.answer) {
          log(`(Answer: ${data.answer})`, 'ai');
        }
        if (data.fallback) {
          log('(Ollama unavailable — fallback riddle used)', 'warning');
        }
      })
      .always(function () {
        $('#riddle-btn').prop('disabled', false).text('Ask the Sphinx 🤖');
      });
  }

  // ── Craft ─────────────────────────────────────────────────────────────
  function doCraft() {
    if (state.inventory.length === 0) {
      log('Nothing in inventory to craft with.', 'warning');
      return;
    }
    const craftLevel = state.character ? state.character.stats.crafting : 3;
    post(API.craft, { materials: state.inventory, crafting_level: craftLevel })
      .done(function (data) {
        if (data.count === 0) {
          log('Nothing craftable with your current supplies.', 'warning');
          $('#craft-results').html('<p style="color:var(--muted);font-size:12px">Nothing craftable yet.</p>').removeClass('hidden');
          return;
        }
        let html = `<p style="font-size:12px;color:var(--muted)">You can craft ${data.count} item(s):</p>`;
        $.each(data.craftable, function (_, item) {
          html += `<div class="craft-item">
            <strong>${item.name}</strong> (lvl ${item.crafting_level})<br>
            <span style="color:var(--muted)">${item.description}</span><br>
            Needs: ${item.materials.join(', ')}
          </div>`;
        });
        $('#craft-results').html(html).removeClass('hidden');
        log(`${data.count} craftable item(s) found with your supplies.`, 'success');
      });
  }

  // ── Log ───────────────────────────────────────────────────────────────
  function log(msg, type) {
    const cls = type ? ` ${type}` : '';
    const now = new Date().toLocaleTimeString('en-US', { hour12: false });
    const $entry = $(`<div class="log-entry${cls}">[${now}] ${msg}</div>`);
    $('#log-entries').prepend($entry);
  }

  // ── UI helpers ────────────────────────────────────────────────────────
  function showError(msg) {
    $('#error-banner').text(msg).removeClass('hidden');
    setTimeout(() => $('#error-banner').addClass('hidden'), 4000);
  }

  // ── Ajax wrappers ─────────────────────────────────────────────────────
  function get(url) {
    showLoading(true);
    return $.ajax({ url, method: 'GET', dataType: 'json' })
      .fail(handleAjaxError)
      .always(() => showLoading(false));
  }

  function post(url, data) {
    showLoading(true);
    return $.ajax({ url, method: 'POST', contentType: 'application/json', data: JSON.stringify(data), dataType: 'json' })
      .fail(handleAjaxError)
      .always(() => showLoading(false));
  }

  function handleAjaxError(xhr) {
    let msg = 'Server error';
    try {
      const err = JSON.parse(xhr.responseText);
      msg = err.error ? `${err.error.code}: ${err.error.message}` : xhr.responseText;
    } catch (_) { msg = xhr.statusText || 'Unknown error'; }
    showError(msg);
  }

  function showLoading(show) {
    $('#loading').toggleClass('hidden', !show);
  }

}(jQuery));
