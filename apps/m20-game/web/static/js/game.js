/* M20 Game — Client-side logic
 * Depends on jQuery 3.7.1 (served locally — no CDN).
 * All state is in-memory + localStorage for the character ID.
 *
 * Gameplay loop:
 *   Map → Click Tile → Buildings → Enter Building → Monster Group → Combat → Loot/XP
 */

(function ($) {
  'use strict';

  // ── State ────────────────────────────────────────────────────────────
  const state = {
    character:        null,
    inventory:        [],
    map:              null,
    currentTile:      null,   // Tile being explored
    encounter:        null,   // {tileID, buildingIdx, building, monster_group, flavor_text, leader_dialogue}
    combatQueue:      [],     // Monsters still alive (with live currentHP)
    activeMonster:    null,   // Current monster being fought
    clearedBuildings: new Set(), // "tileId::buildingIdx"
    firstStrike:      false,  // Gunslinger first-round +2 bonus
  };

  const API = {
    tile:          '/api/tile',
    land:          '/api/land',
    scavenge:      '/api/scavenge',
    items:         '/api/items',
    craft:         '/api/craft',
    combat:        '/api/combat/roll',
    encounter:     '/api/combat/encounter',
    buildingEnter: '/api/building/enter',
    riddle:        '/api/ai/riddle',
    character:     '/api/character',
  };

  // ── Init ─────────────────────────────────────────────────────────────
  $(function () {
    loadClasses();
    restoreSession();

    $('#char-class').on('change', previewClass);
    $('#create-btn').on('click', createCharacter);
    $('#generate-map-btn').on('click', generateMap);
    $('#scavenge-btn').on('click', doScavenge);
    $('#riddle-btn').on('click', doRiddle);
    $('#craft-btn').on('click', doCraft);

    $('#back-to-map-btn').on('click', function () { hideTilePanel(); });
    $('#back-to-tile-btn').on('click', function () { hideBuildingPanel(); });
    $('#combat-roll-btn').on('click', doEncounterRoll);
    $('#combat-flee-btn').on('click', fleeCombat);
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
      name:  name,
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

    const stats  = c.stats;
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
    hideTilePanel();
    hideBuildingPanel();
    post(API.land, { tileCount: 9 }).done(function (data) {
      state.map = data;
      state.clearedBuildings.clear();
      renderMap();
      log('New map generated. 9 tiles. Watch your step.', 'warning');
    });
  }

  const TILE_ICONS = {
    'Ruined City Block':   '🏚',
    'Overgrown Highway':   '🛣',
    'Abandoned Suburb':    '🏠',
    'Gas Station':         '⛽',
    'Hospital':            '🏥',
    'Underground Parking': '🅿',
    'Forest Edge':         '🌲',
    'Military Outpost':    '🪖',
    'Shopping Mall':       '🏬',
    'Dungeon Entrance':    '⚠️',
  };

  function renderMap() {
    if (!state.map) return;
    let html = '';
    $.each(state.map.tiles, function (_, tile) {
      const icon = TILE_ICONS[tile.type.name] || '❓';
      const allCleared = tile.buildings && tile.buildings.length > 0 &&
        tile.buildings.every(function (b, idx) {
          return state.clearedBuildings.has(tile.id + '::' + idx);
        });
      html += `<div class="map-tile danger-${tile.type.danger}${allCleared ? ' explored' : ''}"
                    data-tile-id="${tile.id}">
        <span class="tile-icon">${icon}</span>
        <span class="tile-name">${tile.id}</span>
        <span class="tile-danger">${'☠'.repeat(tile.type.danger)}</span>
      </div>`;
    });
    $('#map-grid').html(html);

    $('#map-grid').off('click', '.map-tile').on('click', '.map-tile', function () {
      const tileID = $(this).data('tile-id');
      const tile   = state.map.tiles.find(function (t) { return t.id === tileID; });
      if (tile) showTilePanel(tile);
    });
  }

  // ── Tile Panel — building list for selected tile ───────────────────────
  function showTilePanel(tile) {
    state.currentTile = tile;
    hideBuildingPanel();

    $('#tile-panel-name').text(tile.type.name);
    $('#tile-panel-desc').text(tile.type.description || '');

    let html = '';
    $.each(tile.buildings, function (idx, bi) {
      const key     = tile.id + '::' + idx;
      const cleared = state.clearedBuildings.has(key);
      const diff    = bi.monster_group.difficulty || 1;
      html += `<div class="building-row${cleared ? ' cleared' : ''}">
        <div class="building-row-info">
          <span class="building-name">${bi.building.name}</span>
          <span class="building-group">${bi.monster_group.name}</span>
          <span class="building-threat">Threat: ${'⚡'.repeat(diff)}</span>
        </div>
        ${cleared
          ? '<span class="cleared-badge">CLEARED</span>'
          : `<button class="btn-enter btn-sm" data-tile-id="${tile.id}" data-idx="${idx}">Enter →</button>`
        }
      </div>`;
    });
    $('#building-list').html(html);
    $('#tile-panel').removeClass('hidden');

    $('#building-list').off('click', '.btn-enter').on('click', '.btn-enter', function () {
      const idx    = parseInt($(this).data('idx'), 10);
      const tileID = $(this).data('tile-id');
      const t      = state.map.tiles.find(function (t) { return t.id === tileID; });
      if (t) enterBuilding(t, idx);
    });
  }

  function hideTilePanel() {
    $('#tile-panel').addClass('hidden');
    state.currentTile = null;
  }

  // ── Building Enter ────────────────────────────────────────────────────
  function enterBuilding(tile, idx) {
    const bi        = tile.buildings[idx];
    const charClass = state.character ? state.character.class : '';

    log(`Entering ${bi.building.name}… ${bi.monster_group.name} awaits.`, 'warning');

    // Ask server for Ollama flavor text; server also regenerates the group.
    // We keep the tile's pre-generated monster_group for combat consistency.
    post(API.buildingEnter, {
      building:        bi.building.name,
      character_class: charClass,
    }).done(function (data) {
      state.encounter = {
        tileID:          tile.id,
        buildingIdx:     idx,
        building:        bi.building,
        monster_group:   bi.monster_group,
        flavor_text:     data.flavor_text,
        leader_dialogue: data.leader_dialogue,
      };
      showBuildingPanel(state.encounter);
    });
  }

  function showBuildingPanel(enc) {
    const { building, monster_group, flavor_text, leader_dialogue } = enc;

    $('#bldg-name').text(building.name);
    $('#bldg-description').text(building.description || '');
    $('#bldg-flavor').text(flavor_text || '');
    $('#bldg-group-name').text(monster_group.name);
    $('#bldg-group-desc').text(monster_group.description || '');
    $('#bldg-leader-dialogue').text(leader_dialogue ? `"${leader_dialogue}"` : '');

    let html = '';
    $.each(monster_group.monsters, function (_, m) {
      html += `<div class="monster-card" data-name="${m.name}">
        <div class="monster-card-info">
          <span class="monster-name">${m.name}</span>
          <span class="monster-desc">${m.description || ''}</span>
        </div>
        <div class="monster-card-stats">
          <span class="stat-chip">HP ${m.hp}</span>
          <span class="stat-chip">ATK +${m.attack}</span>
          <span class="stat-chip">DEF ${m.defense}</span>
          <span class="stat-chip xp-chip">+${m.xp_reward} XP</span>
        </div>
      </div>`;
    });
    $('#monster-group-list').html(html);

    $('#combat-section').addClass('hidden');
    $('#fight-section').show().html(
      `<button id="fight-btn" class="btn-primary fight-btn">⚔ Fight! (${monster_group.monsters.length} enemies)</button>`
    );
    $('#fight-btn').off('click').on('click', function () {
      startCombat(monster_group.monsters);
    });

    $('#building-panel').removeClass('hidden');

    // Scroll panel into view
    $('#building-panel')[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function hideBuildingPanel() {
    $('#building-panel').addClass('hidden');
    hideCombatSection();
    state.encounter     = null;
    state.combatQueue   = [];
    state.activeMonster = null;
    state.firstStrike   = false;
  }

  // ── Combat ────────────────────────────────────────────────────────────
  function startCombat(monsters) {
    state.combatQueue = monsters.map(function (m) {
      return Object.assign({}, m, { currentHP: m.hp });
    });
    state.firstStrike = state.character && state.character.class === 'Gunslinger';
    $('#fight-section').hide();
    nextMonster();
  }

  function nextMonster() {
    if (state.combatQueue.length === 0) {
      onGroupDefeated();
      return;
    }
    state.activeMonster = state.combatQueue.shift();
    showCombatPanel(state.activeMonster);
    log(`⚔ Now facing: ${state.activeMonster.name} (HP: ${state.activeMonster.currentHP})`, 'combat');
  }

  function showCombatPanel(monster) {
    $('#combat-monster-name').text(monster.name);
    $('#combat-monster-desc').text(monster.description || '');
    updateMonsterHP(monster);
    $('#combat-narration').text('');
    $('#combat-roll-btn').prop('disabled', false).text('Roll Attack');
    $('#combat-flee-btn').prop('disabled', false);
    $('#combat-section').removeClass('hidden');

    // Highlight active monster card
    $('#monster-group-list .monster-card').removeClass('active');
    $(`#monster-group-list .monster-card[data-name="${monster.name}"]`).addClass('active');

    $('#combat-section')[0].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function hideCombatSection() {
    $('#combat-section').addClass('hidden');
    state.activeMonster = null;
  }

  function updateMonsterHP(monster) {
    const pct   = Math.max(0, Math.round((monster.currentHP / monster.hp) * 100));
    const cls   = pct > 60 ? 'hp-high' : pct > 25 ? 'hp-mid' : 'hp-low';
    $('#combat-hp-bar').css('width', pct + '%').attr('class', 'hp-fill ' + cls);
    $('#combat-hp-text').text(monster.currentHP + ' / ' + monster.hp);
  }

  // Pick the relevant stat and bonuses based on character class
  function getCombatStat() {
    if (!state.character) return { stat: 3, bonus: 0, critThreshold: 20 };
    const stats = state.character.stats;
    const cls   = state.character.class;
    let stat = stats.strength, bonus = 0, critThreshold = 20;

    switch (cls) {
      case 'Gunslinger':
        stat = stats.marksmanship;
        if (state.firstStrike) { bonus = 2; state.firstStrike = false; }
        break;
      case 'Brawler':
        stat = stats.strength;
        critThreshold = 18;   // Brawler: "Crit threshold -2"
        break;
      case 'Medic':
        stat = stats.stamina;
        break;
      case 'Scavenger':
      case 'Conspiracy Theorist':
        stat = stats.scouting;
        break;
      case 'Wrench Witch':
      case 'Street Pharmacist':
        stat = stats.crafting;
        break;
      case 'Hoarder':
        stat = stats.salvaging;
        break;
    }
    return { stat: stat, bonus: bonus, critThreshold: critThreshold };
  }

  function doEncounterRoll() {
    const monster = state.activeMonster;
    if (!monster) return;

    const { stat, bonus, critThreshold } = getCombatStat();
    const charClass = state.character ? state.character.class : 'Survivor';

    $('#combat-roll-btn').prop('disabled', true).text('Rolling…');

    post(API.encounter, {
      monster:         monster.name,
      stat:            stat,
      bonus:           bonus,
      character_class: charClass,
      crit_threshold:  critThreshold,
    }).done(function (data) {
      const roll    = data.roll;
      const hit     = data.hit;
      const outcome = roll.outcome;

      $('#combat-narration').text(data.narration);

      log('[' + monster.name + '] d20:' + roll.roll + ' + stat:' + roll.stat_value +
          ' + bonus:' + roll.bonus + ' = ' + roll.total + ' → ' + outcome.toUpperCase(), 'combat');
      log(data.narration, hit ? 'success' : 'combat');

      if (hit) {
        const isCrit = outcome === 'crit_success';
        const dmg    = rollPlayerDamage(isCrit);
        monster.currentHP = Math.max(0, monster.currentHP - dmg);
        updateMonsterHP(monster);
        log('  → You deal ' + dmg + ' damage. ' + monster.name + ' has ' + monster.currentHP + ' HP left.', 'success');

        if (monster.currentHP <= 0) {
          log('  → ' + monster.name + ' is down!', 'success');
          $(`#monster-group-list .monster-card[data-name="${monster.name}"]`).addClass('defeated');
          onMonsterDefeated(monster);
          return;
        }
      } else {
        const counterDmg = rollMonsterDamage(monster, outcome === 'crit_failure');
        takeDamage(counterDmg);
        log('  → ' + monster.name + ' strikes back! You take ' + counterDmg +
            ' damage. HP: ' + state.character.hp + '/' + state.character.max_hp, 'combat');

        if (state.character.hp <= 0) {
          onPlayerDefeated();
          return;
        }
      }

      $('#combat-roll-btn').prop('disabled', false).text('Roll Attack');
    });
  }

  function rollPlayerDamage(isCrit) {
    const d6 = function () { return Math.floor(Math.random() * 6) + 1; };
    return isCrit ? d6() + d6() : d6();
  }

  function rollMonsterDamage(monster, isCritFail) {
    // Normal miss: 1 + floor(attack / 3) damage (minimal but real)
    // Crit fail:   full attack stat (serious consequence)
    return isCritFail ? Math.max(2, monster.attack) : 1 + Math.floor(monster.attack / 3);
  }

  function takeDamage(amount) {
    if (!state.character) return;
    state.character.hp = Math.max(0, state.character.hp - amount);
    renderStats();
    $('#hp-display').addClass('hp-damaged');
    setTimeout(function () { $('#hp-display').removeClass('hp-damaged'); }, 600);
  }

  function awardXP(amount) {
    if (!state.character) return;
    state.character.xp = (state.character.xp || 0) + amount;
    const xpNeeded = state.character.level * 100;
    if (state.character.xp >= xpNeeded) {
      state.character.level++;
      state.character.xp -= xpNeeded;
      state.character.max_hp += 4;
      state.character.hp = Math.min(state.character.hp + 4, state.character.max_hp);
      log('✨ LEVEL UP! You are now level ' + state.character.level + '. Max HP +4!', 'success');
    }
    renderStats();
  }

  function onMonsterDefeated(monster) {
    awardXP(monster.xp_reward);
    log('  → +' + monster.xp_reward + ' XP', 'success');
    $('#combat-roll-btn').prop('disabled', true).text('Next…');
    setTimeout(function () { nextMonster(); }, 1400);
  }

  function onGroupDefeated() {
    hideCombatSection();

    const enc = state.encounter;
    if (!enc) return;

    // Mark building cleared using tile-id::buildingIdx key
    const key = enc.tileID + '::' + enc.buildingIdx;
    state.clearedBuildings.add(key);

    log('🏆 ' + enc.monster_group.name + ' defeated! ' + enc.building.name + ' is clear.', 'success');

    // Victory state in building panel
    $('#fight-section').show().html(
      '<div class="cleared-victory">🏆 CLEARED — searching for supplies…</div>'
    );

    // Loot drop from scavenge
    const level = state.character ? state.character.stats.scouting : 3;
    get(API.scavenge + '?level=' + level).done(function (data) {
      const max = state.character && state.character.class === 'Hoarder' ? 8 : 5;
      $.each(data.found, function (_, item) {
        if (state.inventory.length < max) {
          state.inventory.push(item.name);
          log('  → Looted: ' + item.name, 'success');
        } else {
          log('  → Inventory full. Left behind: ' + item.name, 'warning');
        }
      });
      renderInventory();
    });

    // Refresh map to show tile cleared indicator
    renderMap();
  }

  function onPlayerDefeated() {
    hideCombatSection();
    log('💀 You have been defeated. You crawl away, barely alive.', 'combat');
    state.character.hp  = 1;
    state.combatQueue   = [];
    state.activeMonster = null;
    renderStats();
    $('#fight-section').show().html(
      '<div style="color:var(--accent);font-size:12px">You escaped — barely.</div>'
    );
  }

  function fleeCombat() {
    const mName = state.activeMonster ? state.activeMonster.name : 'the enemy';
    log('You flee from ' + mName + '. Not every fight is yours to win.', 'warning');
    hideCombatSection();
    state.combatQueue   = [];
    state.activeMonster = null;
    state.firstStrike   = false;
    $('#fight-section').show().html(
      '<div style="color:var(--accent2);font-size:12px">You fled. The building is still theirs.</div>'
    );
  }

  // ── Scavenge ──────────────────────────────────────────────────────────
  function doScavenge() {
    const level = state.character ? state.character.stats.scouting : 3;
    get(API.scavenge + '?level=' + level).done(function (data) {
      log('Scavenge (scout ' + level + '): ' + data.description);
      const max = state.character.class === 'Hoarder' ? 8 : 5;
      $.each(data.found, function (_, item) {
        if (state.inventory.length < max) {
          state.inventory.push(item.name);
          log('  → Found: ' + item.name, 'success');
        } else {
          log('  → Inventory full. Left behind: ' + item.name, 'warning');
        }
      });
      renderInventory();
    });
  }

  // ── Riddle (Ollama AI) ────────────────────────────────────────────────
  function doRiddle() {
    log('The Sphinx regards you with ancient patience…', 'ai');
    $('#riddle-btn').prop('disabled', true).text('Asking the Sphinx…');
    get(API.riddle)
      .done(function (data) {
        log('SPHINX: "' + data.riddle + '"', 'ai');
        if (data.answer) { log('(Answer: ' + data.answer + ')', 'ai'); }
        if (data.fallback) { log('(Ollama unavailable — fallback riddle used)', 'warning'); }
      })
      .always(function () {
        $('#riddle-btn').prop('disabled', false).text('Ask the Sphinx 🤖');
      });
  }

  // ── Craft ─────────────────────────────────────────────────────────────
  function doCraft() {
    if (state.inventory.length === 0) { log('Nothing in inventory to craft with.', 'warning'); return; }
    const craftLevel = state.character ? state.character.stats.crafting : 3;
    post(API.craft, { materials: state.inventory, crafting_level: craftLevel })
      .done(function (data) {
        if (data.count === 0) {
          log('Nothing craftable with your current supplies.', 'warning');
          $('#craft-results').html('<p style="color:var(--muted);font-size:12px">Nothing craftable yet.</p>').removeClass('hidden');
          return;
        }
        let html = '<p style="font-size:12px;color:var(--muted)">You can craft ' + data.count + ' item(s):</p>';
        $.each(data.craftable, function (_, item) {
          html += `<div class="craft-item">
            <strong>${item.name}</strong> (lvl ${item.crafting_level})<br>
            <span style="color:var(--muted)">${item.description}</span><br>
            Needs: ${item.materials.join(', ')}
          </div>`;
        });
        $('#craft-results').html(html).removeClass('hidden');
        log(data.count + ' craftable item(s) found with your supplies.', 'success');
      });
  }

  // ── Log ───────────────────────────────────────────────────────────────
  function log(msg, type) {
    const cls  = type ? ' ' + type : '';
    const now  = new Date().toLocaleTimeString('en-US', { hour12: false });
    const $row = $('<div class="log-entry' + cls + '">[' + now + '] ' + msg + '</div>');
    $('#log-entries').prepend($row);
  }

  // ── UI helpers ────────────────────────────────────────────────────────
  function showError(msg) {
    $('#error-banner').text(msg).removeClass('hidden');
    setTimeout(function () { $('#error-banner').addClass('hidden'); }, 4000);
  }

  // ── Ajax wrappers ─────────────────────────────────────────────────────
  function get(url) {
    showLoading(true);
    return $.ajax({ url: url, method: 'GET', dataType: 'json' })
      .fail(handleAjaxError)
      .always(function () { showLoading(false); });
  }

  function post(url, data) {
    showLoading(true);
    return $.ajax({
      url:         url,
      method:      'POST',
      contentType: 'application/json',
      data:        JSON.stringify(data),
      dataType:    'json',
    }).fail(handleAjaxError)
      .always(function () { showLoading(false); });
  }

  function handleAjaxError(xhr) {
    let msg = 'Server error';
    try {
      const err = JSON.parse(xhr.responseText);
      msg = err.error ? err.error.code + ': ' + err.error.message : xhr.responseText;
    } catch (_) { msg = xhr.statusText || 'Unknown error'; }
    showError(msg);
  }

  function showLoading(show) {
    $('#loading').toggleClass('hidden', !show);
  }

}(jQuery));
