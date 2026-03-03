/* M20 Game — Sprint 3: Party, Initiative, Tile Draw, Character Sheet
 * Depends on jQuery 3.7.1 (served locally — no CDN).
 *
 * Gameplay loop:
 *   Draw Tiles → Pick One → Place on Map → Explore → Fight → Loot → Level Up
 * Party: up to 4 characters, initiative-based combat, character sheet modal.
 */

(function ($) {
  'use strict';

  // ── State ────────────────────────────────────────────────────────────
  const state = {
    // Core character / party
    character:        null,    // active character (primary party member)
    party:            [],      // array of Character objects (up to 4)
    activePartyIdx:   0,       // which party member is acting in combat

    // Map & exploration
    map:              null,
    placedTiles:      [],      // tiles placed on map (in order)
    tileHand:         [],      // 2 tile options drawn for selection
    exitTileIdx:      -1,      // index in placedTiles of exit tile (-1 = not yet)
    currentTile:      null,

    // Combat
    encounter:        null,
    combatQueue:      [],
    activeMonster:    null,
    clearedBuildings: new Set(),
    firstStrike:      false,

    // Initiative system
    initiativeOrder:  [],      // [{type, name, idx, initiative, ref?, hp?, maxHp?}]
    initiativeTurn:   0,       // index into initiativeOrder

    // Shared game data from /api/items
    equipBonuses:     {},
    specialGroups:    {},
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

  // Class → emoji mapping
  const CLASS_EMOJI = {
    'Brawler':              '💪',
    'Gunslinger':           '🔫',
    'Medic':                '💉',
    'Scavenger':            '🔦',
    'Wrench Witch':         '🔧',
    'Street Pharmacist':    '💊',
    'Hoarder':              '🎒',
    'Conspiracy Theorist':  '📻',
  };

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

  // ── Init ─────────────────────────────────────────────────────────────
  $(function () {
    loadItemData();
    loadClasses();
    restoreSession();

    $('#char-class').on('change', previewClass);
    $('#create-btn').on('click', createCharacter);
    $('#add-party-btn').on('click', showAddPartyForm);
    $('#generate-map-btn').on('click', generateClassicMap);
    $('#draw-tile-btn').on('click', drawTileHand);
    $('#scavenge-btn').on('click', doScavenge);
    $('#riddle-btn').on('click', doRiddle);
    $('#craft-check-btn').on('click', doCraftCheck);
    $('#back-to-map-btn').on('click', hideTilePanel);
    $('#back-to-tile-btn').on('click', hideBuildingPanel);
    $('#combat-roll-btn').on('click', doEncounterRoll);
    $('#combat-flee-btn').on('click', fleeCombat);
    $('#hp-display').on('click', function () {
      if (state.character) openCharSheet(state.character);
    });
    $('#char-sheet-close').on('click', function () {
      $('#char-sheet-modal').addClass('hidden');
    });
  });

  // ── Load shared game data ─────────────────────────────────────────────
  function loadItemData() {
    get(API.items).done(function (data) {
      state.equipBonuses  = data.equip_bonuses  || {};
      state.specialGroups = data.special_groups || {};
    });
  }

  // ── Session restore ───────────────────────────────────────────────────
  function restoreSession() {
    // Restore all party members from localStorage
    const ids = JSON.parse(localStorage.getItem('m20_party_ids') || '[]');
    if (!ids.length) {
      const single = localStorage.getItem('m20_char_id');
      if (single) ids.push(single);
    }
    if (!ids.length) return;

    let loaded = 0;
    const results = [];
    ids.forEach(function (id, i) {
      get(API.character + '/' + id + '/sheet')
        .done(function (data) { results[i] = data.character; })
        .always(function () {
          loaded++;
          if (loaded === ids.length) {
            const valid = results.filter(Boolean);
            if (valid.length > 0) {
              valid.forEach(function (c) { addToParty(c, true); });
              showGame();
              log('Welcome back! Party of ' + valid.length + ' restored.', 'success');
              drawTileHand();
            }
          }
        });
    });
  }

  function savePartyIDs() {
    const ids = state.party.map(function (c) { return c.id; });
    localStorage.setItem('m20_party_ids', JSON.stringify(ids));
    if (ids.length > 0) {
      localStorage.setItem('m20_char_id', ids[0]);
    }
  }

  // ── Persist character to server ───────────────────────────────────────
  function saveCharacter(char) {
    if (!char || !char.id) return;
    return put(API.character + '/' + char.id, {
      hp:        char.hp,
      xp:        char.xp,
      level:     char.level,
      inventory: char.inventory,
      equipment: char.equipment || {},
      location:  char.location || 'tile-01',
    }).done(function (saved) {
      // Sync saved state back (server may adjust HP bounds etc.)
      const idx = state.party.findIndex(function (c) { return c.id === saved.id; });
      if (idx !== -1) {
        state.party[idx] = saved;
        if (idx === 0) state.character = saved;
      }
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
      const cls = data.classes.find(function (c) { return c.name === chosen; });
      if (!cls) return;
      const bonuses = Object.entries(cls.bonus_stats || {})
        .map(function ([k, v]) { return k + ' +' + v; })
        .join(', ');
      $('#class-info').html(
        '<div class="flavor">"' + cls.flavor + '"</div>' +
        '<strong>Special:</strong> ' + cls.special_ability + '<br>' +
        '<strong>Bonuses:</strong> ' + bonuses
      ).removeClass('hidden');
    });
  }

  function createCharacter() {
    const name = $('#char-name').val().trim();
    if (!name) { showError('Enter a survivor name.'); return; }
    if (state.party.length >= 4) { showError('Party is full (max 4 survivors).'); return; }

    post(API.character, {
      name:  name,
      class: $('#char-class').val() || '',
    }).done(function (c) {
      addToParty(c, false);
      savePartyIDs();
      showGame();
      log(c.name + ' the ' + c.class + ' joins the party! HP: ' + c.hp + '/' + c.max_hp, 'success');
      if (state.placedTiles.length === 0) drawTileHand();
    });
  }

  function showAddPartyForm() {
    if (state.party.length >= 4) { showError('Party is full (max 4 survivors).'); return; }
    // Show the create section briefly, scrolling to it
    $('#create-section').removeClass('hidden');
    $('#create-section')[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ── Party management ──────────────────────────────────────────────────
  function addToParty(char, silent) {
    if (state.party.length >= 4) return;
    state.party.push(char);
    if (!state.character) {
      state.character = char;
      state.activePartyIdx = 0;
    }
    if (!silent) renderPartyBar();
  }

  function activeChar() {
    return state.party[state.activePartyIdx] || state.character;
  }

  function renderPartyBar() {
    if (state.party.length === 0) {
      $('#party-bar').addClass('hidden');
      return;
    }
    $('#party-bar').removeClass('hidden');

    let html = '';
    $.each(state.party, function (idx, char) {
      const emoji    = CLASS_EMOJI[char.class] || '🧍';
      const hpPct    = Math.round((char.hp / char.max_hp) * 100);
      const hpColor  = hpPct > 60 ? 'var(--success)' : hpPct > 25 ? 'var(--accent2)' : 'var(--accent)';
      const isDead   = char.hp <= 0;
      const isActive = idx === state.activePartyIdx;

      html += '<div class="party-slot' +
              (isActive ? ' active-turn' : '') +
              (isDead   ? ' dead'        : '') +
              '" data-party-idx="' + idx + '" title="Click to view ' + char.name + '\'s sheet">' +
              '<div class="party-slot-header">' +
                '<span class="party-slot-emoji">' + emoji + '</span>' +
                '<span class="party-slot-name">' + char.name + '</span>' +
              '</div>' +
              '<div class="party-hp-bar">' +
                '<div class="party-hp-fill" style="width:' + hpPct + '%;background:' + hpColor + '"></div>' +
              '</div>' +
              '<div class="party-hp-text">HP ' + char.hp + '/' + char.max_hp + ' · Lv' + char.level + '</div>' +
              '</div>';
    });
    $('#party-slots').html(html);

    $('#party-slots').off('click', '.party-slot').on('click', '.party-slot', function () {
      const idx  = parseInt($(this).data('party-idx'), 10);
      const char = state.party[idx];
      if (char) openCharSheet(char);
    });
  }

  // ── Show game UI ──────────────────────────────────────────────────────
  function showGame() {
    $('#create-section').addClass('hidden');
    $('#game-section').removeClass('hidden');
    renderStats();
    renderInventoryGrid(state.character);
    renderPartyBar();
    renderFogMap();
  }

  function renderStats() {
    const c = state.character;
    if (!c) return;

    $('#char-name-display').text(c.name);
    $('#char-class-display').text('[' + c.class + ']');
    $('#hp-display').text('HP ' + c.hp + '/' + c.max_hp);

    const stats  = c.stats;
    const labels = {
      strength: 'STR', stamina: 'STA', marksmanship: 'MRK',
      scouting: 'SCT', scavenging: 'SCG', crafting: 'CRF', salvaging: 'SLV',
    };
    let html = '';
    $.each(labels, function (key, label) {
      html += '<div class="stat-item">' +
              '<span class="stat-label">' + label + '</span>' +
              '<span class="stat-value">' + stats[key] + '</span>' +
              '</div>';
    });
    html += '<div class="stat-item"><span class="stat-label">LVL</span><span class="stat-value">' + c.level + '</span></div>' +
            '<div class="stat-item"><span class="stat-label">XP</span><span class="stat-value">' + c.xp + '</span></div>';
    $('#stats-bar').html(html);
  }

  // ── Inventory grid ────────────────────────────────────────────────────
  function renderInventoryGrid(char) {
    if (!char) return;
    const max  = char.class === 'Hoarder' ? 25 : 20;
    const inv  = char.inventory || [];
    const equip = char.equipment || {};

    $('#inv-count').text('(' + inv.length + '/' + max + ')');

    let html = '';
    for (let i = 0; i < max; i++) {
      if (i < inv.length) {
        const item     = inv[i];
        const isEquip  = equip.weapon === item || equip.armor === item || equip.accessory === item;
        const slotLabel = equip.weapon === item ? '⚔ weapon' : equip.armor === item ? '🛡 armor' : equip.accessory === item ? '✨ accessory' : '';
        html += '<div class="inv-slot' + (isEquip ? ' equipped' : '') + '" data-item="' + encodeURIComponent(item) + '" data-char-id="' + char.id + '">' +
                item +
                (slotLabel ? '<span class="equipped-badge">' + slotLabel + '</span>' : '') +
                '</div>';
      } else {
        html += '<div class="inv-slot empty">—</div>';
      }
    }
    $('#inventory-grid').html(html);

    // Click to show action menu
    $('#inventory-grid').off('click', '.inv-slot:not(.empty)').on('click', '.inv-slot:not(.empty)', function (e) {
      e.stopPropagation();
      const $slot   = $(this);
      const itemName = decodeURIComponent($slot.data('item'));
      const charId   = $slot.data('char-id');
      const char     = state.party.find(function (c) { return c.id === charId; }) || state.character;
      showItemMenu($slot, itemName, char);
    });

    // Close menu on outside click
    $(document).off('click.invmenu').on('click.invmenu', function () {
      $('.item-menu').remove();
    });
  }

  function showItemMenu($slot, itemName, char) {
    $('.item-menu').remove();
    const isEquippable = !!state.equipBonuses[itemName];
    const isMedical    = ['Bandage', 'Painkillers', 'First Aid Kit', 'Medkit'].includes(itemName);
    const equip        = char.equipment || {};
    const isEquipped   = equip.weapon === itemName || equip.armor === itemName || equip.accessory === itemName;

    let menuHTML = '<div class="item-menu">';
    if (isEquippable && !isEquipped) {
      menuHTML += '<button class="item-menu-btn" data-action="equip-weapon">⚔ Equip as Weapon</button>' +
                  '<button class="item-menu-btn" data-action="equip-armor">🛡 Equip as Armor</button>' +
                  '<button class="item-menu-btn" data-action="equip-accessory">✨ Equip as Accessory</button>';
    }
    if (isEquipped) {
      menuHTML += '<button class="item-menu-btn" data-action="unequip">↩ Unequip</button>';
    }
    if (isMedical) {
      menuHTML += '<button class="item-menu-btn" data-action="use">💊 Use</button>';
    }
    menuHTML += '<button class="item-menu-btn danger" data-action="drop">🗑 Drop</button>';
    menuHTML += '</div>';

    const $menu = $(menuHTML);
    $slot.css('position', 'relative').append($menu);

    $menu.on('click', '.item-menu-btn', function (e) {
      e.stopPropagation();
      const action = $(this).data('action');
      $('.item-menu').remove();
      switch (action) {
        case 'equip-weapon':    doEquipItem(char, 'weapon',    itemName); break;
        case 'equip-armor':     doEquipItem(char, 'armor',     itemName); break;
        case 'equip-accessory': doEquipItem(char, 'accessory', itemName); break;
        case 'unequip':         doUnequipItem(char, itemName);            break;
        case 'use':             doUseItem(char, itemName);                break;
        case 'drop':            doDropItem(char, itemName);               break;
      }
    });
  }

  // ── Character Sheet Modal ─────────────────────────────────────────────
  function openCharSheet(char) {
    renderCharSheet(char);
    $('#char-sheet-modal').removeClass('hidden');
  }

  function renderCharSheet(char) {
    const equip    = char.equipment  || {};
    const inv      = char.inventory  || [];
    const stats    = char.stats      || {};
    const max      = char.class === 'Hoarder' ? 25 : 20;
    const xpNeeded = char.level * 100;
    const xpPct    = Math.min(100, Math.round((char.xp / xpNeeded) * 100));
    const emoji    = CLASS_EMOJI[char.class] || '🧍';

    $('#csh-title').text(emoji + ' ' + char.name);
    $('#csh-identity').html(
      '<strong>' + char.class + '</strong> · Level ' + char.level +
      ' · HP <span style="color:var(--success)">' + char.hp + '/' + char.max_hp + '</span>'
    );
    $('#csh-xp-bar').css('width', xpPct + '%');
    $('#csh-xp-text').text('XP: ' + char.xp + ' / ' + xpNeeded + ' (' + xpPct + '% to level up)');

    // Stats
    const statLabels = {
      strength: 'Strength', stamina: 'Stamina', marksmanship: 'Marksmanship',
      scouting: 'Scouting', scavenging: 'Scavenging', crafting: 'Crafting', salvaging: 'Salvaging',
    };
    let statsHTML = '';
    $.each(statLabels, function (key, label) {
      statsHTML += '<div class="csh-stat-row">' +
                   '<span class="stat-label">' + label + '</span>' +
                   '<span class="stat-value">' + (stats[key] || 0) + '</span>' +
                   '</div>';
    });
    $('#csh-stats').html(statsHTML);

    // Equipment slots
    const slots = [
      { key: 'weapon',    label: '⚔ Weapon' },
      { key: 'armor',     label: '🛡 Armor' },
      { key: 'accessory', label: '✨ Accessory' },
    ];
    let equipHTML = '';
    $.each(slots, function (_, slot) {
      const item    = equip[slot.key] || '';
      const bonuses = item && state.equipBonuses[item]
        ? Object.entries(state.equipBonuses[item]).map(function ([k, v]) { return k + ' +' + v; }).join(', ')
        : '';
      equipHTML += '<div class="equip-slot">' +
                   '<span class="equip-slot-label">' + slot.label + '</span>' +
                   '<span class="equip-slot-item' + (item ? '' : ' empty') + '">' +
                   (item ? item + (bonuses ? '<span style="color:var(--success);font-size:10px"> (' + bonuses + ')</span>' : '') : '— empty —') +
                   '</span>' +
                   (item ? '<button class="btn-sm equip-unequip-btn" data-slot="' + slot.key + '" data-char-id="' + char.id + '">Unequip</button>' : '') +
                   '</div>';
    });
    $('#csh-equipment').html(equipHTML);

    $('#csh-equipment').off('click', '.equip-unequip-btn').on('click', '.equip-unequip-btn', function () {
      const slot   = $(this).data('slot');
      const charId = $(this).data('char-id');
      const c      = state.party.find(function (x) { return x.id === charId; }) || state.character;
      doEquipItem(c, slot, '');
    });

    // Inventory grid in modal
    $('#csh-inv-count').text('(' + inv.length + '/' + max + ')');
    let invHTML = '';
    for (let i = 0; i < max; i++) {
      if (i < inv.length) {
        const item    = inv[i];
        const isEq    = equip.weapon === item || equip.armor === item || equip.accessory === item;
        const slotLbl = equip.weapon === item ? '⚔' : equip.armor === item ? '🛡' : equip.accessory === item ? '✨' : '';
        invHTML += '<div class="inv-slot' + (isEq ? ' equipped' : '') + '" data-item="' + encodeURIComponent(item) + '" data-char-id="' + char.id + '">' +
                   item + (slotLbl ? '<span class="equipped-badge">' + slotLbl + '</span>' : '') +
                   '</div>';
      } else {
        invHTML += '<div class="inv-slot empty">—</div>';
      }
    }
    $('#csh-inventory-grid').html(invHTML);

    $('#csh-inventory-grid').off('click', '.inv-slot:not(.empty)').on('click', '.inv-slot:not(.empty)', function (e) {
      e.stopPropagation();
      const $slot   = $(this);
      const itemName = decodeURIComponent($slot.data('item'));
      const charId   = $slot.data('char-id');
      const c        = state.party.find(function (x) { return x.id === charId; }) || state.character;
      showItemMenu($slot, itemName, c);
    });

    // Craftable items list
    const craftLevel = char.stats.crafting || 0;
    const allCraftable = [];
    // We need to call /api/items to get craftable list, but we can check locally
    get(API.items).done(function (data) {
      const items = data.craftable || [];
      const invMap = {};
      inv.forEach(function (item) { invMap[item] = (invMap[item] || 0) + 1; });

      let craftHTML = '';
      items.forEach(function (item) {
        if (item.crafting_level > craftLevel) return;
        const needed = {};
        item.materials.forEach(function (m) { needed[m] = (needed[m] || 0) + 1; });
        const canMake = Object.keys(needed).every(function (m) { return (invMap[m] || 0) >= needed[m]; });
        if (canMake) {
          craftHTML += '<div class="craft-item">' +
                       '<strong>' + item.name + '</strong>' +
                       (item.equippable ? ' <span style="color:var(--success);font-size:10px">[equippable]</span>' : '') +
                       '<br><span style="color:var(--muted)">' + item.description + '</span>' +
                       '<br>Needs: ' + item.materials.join(', ') +
                       '<br><button class="btn-sm craft-now-btn" data-item="' + encodeURIComponent(item.name) + '" data-char-id="' + char.id + '" style="margin-top:4px">Craft it!</button>' +
                       '</div>';
        }
      });
      if (!craftHTML) {
        craftHTML = '<p style="font-size:12px;color:var(--muted)">Nothing craftable with your current supplies.</p>';
      }
      $('#csh-craftable-list').html(craftHTML);
    });

    $('#csh-craftable-list').off('click', '.craft-now-btn').on('click', '.craft-now-btn', function () {
      const itemName = decodeURIComponent($(this).data('item'));
      const charId   = $(this).data('char-id');
      const c        = state.party.find(function (x) { return x.id === charId; }) || state.character;
      doCraftItem(c, itemName);
    });
  }

  // ── Inventory actions ─────────────────────────────────────────────────
  function doEquipItem(char, slot, item) {
    post(API.character + '/' + char.id + '/equip', { slot: slot, item: item })
      .done(function (updated) {
        syncCharacter(updated);
        const msg = item ? 'Equipped ' + item + ' as ' + slot + '.' : 'Unequipped ' + slot + '.';
        log(msg, 'success');
        renderInventoryGrid(state.character);
        if ($('#char-sheet-modal').is(':not(.hidden)')) {
          renderCharSheet(updated);
        }
      });
  }

  function doUnequipItem(char, itemName) {
    const equip = char.equipment || {};
    let slot = '';
    if (equip.weapon === itemName)    slot = 'weapon';
    else if (equip.armor === itemName) slot = 'armor';
    else if (equip.accessory === itemName) slot = 'accessory';
    if (slot) doEquipItem(char, slot, '');
  }

  function doDropItem(char, itemName) {
    post(API.character + '/' + char.id + '/item/drop', { item_name: itemName })
      .done(function (updated) {
        syncCharacter(updated);
        log('Dropped: ' + itemName, 'warning');
        renderInventoryGrid(state.character);
        if ($('#char-sheet-modal').is(':not(.hidden)')) renderCharSheet(updated);
      });
  }

  function doUseItem(char, itemName) {
    // Use a medical item: restore HP then drop
    const healing = { 'Bandage': 3, 'Painkillers': 2, 'First Aid Kit': 6, 'Medkit': 10 };
    const amount  = healing[itemName] || 2;
    const newHP   = Math.min(char.hp + amount, char.max_hp);
    char.hp = newHP;
    log('Used ' + itemName + ': +' + amount + ' HP → ' + char.hp + '/' + char.max_hp, 'success');
    doDropItem(char, itemName);
    renderStats();
    renderPartyBar();
  }

  function doCraftItem(char, itemName) {
    post(API.character + '/' + char.id + '/craft', { item_name: itemName })
      .done(function (updated) {
        syncCharacter(updated);
        log('🔨 Crafted: ' + itemName + '!', 'success');
        renderInventoryGrid(state.character);
        if ($('#char-sheet-modal').is(':not(.hidden)')) renderCharSheet(updated);
      });
  }

  function syncCharacter(updated) {
    const idx = state.party.findIndex(function (c) { return c.id === updated.id; });
    if (idx !== -1) {
      state.party[idx] = updated;
      if (idx === 0) {
        state.character = updated;
      }
    }
  }

  // ── Map — fog grid ────────────────────────────────────────────────────
  function renderFogMap() {
    // 5×5 grid with fog for unplaced slots
    const total = 25;
    let html = '';
    for (let i = 0; i < total; i++) {
      if (i < state.placedTiles.length) {
        const tile = state.placedTiles[i];
        const icon = TILE_ICONS[tile.type.name] || '❓';
        const allCleared = tile.buildings && tile.buildings.length > 0 &&
          tile.buildings.every(function (b, idx) {
            return state.clearedBuildings.has(tile.id + '::' + idx);
          });
        const isExit = i === state.exitTileIdx;
        html += '<div class="map-tile danger-' + tile.type.danger +
                (allCleared ? ' explored' : '') +
                (isExit     ? ' exit-tile-placed' : '') +
                '" data-tile-id="' + tile.id + '">' +
                '<span class="tile-icon">' + (isExit ? '🚪' : icon) + '</span>' +
                '<span class="tile-name">' + tile.id.slice(-4) + '</span>' +
                '<span class="tile-danger">' + '☠'.repeat(tile.type.danger) + '</span>' +
                '</div>';
      } else {
        html += '<div class="map-tile fog"><span class="tile-icon">🌫</span></div>';
      }
    }
    $('#map-grid').html(html).css('grid-template-columns', 'repeat(5, 1fr)');

    $('#map-grid').off('click', '.map-tile:not(.fog)').on('click', '.map-tile:not(.fog)', function () {
      const tileID = $(this).data('tile-id');
      const tile   = state.placedTiles.find(function (t) { return t.id === tileID; });
      if (tile) showTilePanel(tile);
    });
  }

  // ── Tile Draw Mechanic ────────────────────────────────────────────────
  function drawTileHand() {
    if (state.placedTiles.length >= 25) {
      log('The map is full. Nowhere left to go.', 'warning');
      return;
    }

    $('#draw-tile-btn').prop('disabled', true).text('Drawing…');
    state.tileHand = [];

    // Draw 2 tiles in parallel
    const p1 = get(API.tile);
    const p2 = get(API.tile);

    $.when(p1, p2).done(function (r1, r2) {
      const t1 = r1[0];
      const t2 = r2[0];

      // After 5 tiles placed: 25% chance one tile is the exit tile
      const maybeExit = state.placedTiles.length >= 5 && state.exitTileIdx === -1 && Math.random() < 0.25;
      if (maybeExit) {
        state.tileHand = [t1, makeExitTile()];
      } else {
        state.tileHand = [t1, t2];
      }

      renderTileHand();
    }).always(function () {
      $('#draw-tile-btn').prop('disabled', false).text('Draw Tiles');
    });
  }

  function makeExitTile() {
    // Build a fake tile object representing the exit door with the Windego Den
    return {
      id:       'exit-' + Date.now().toString(36),
      isExit:   true,
      type: {
        name:        'Exit Door',
        description: "There's a door here. Something very big is standing in front of it.",
        danger:       5,
      },
      buildings: [{
        building: { name: 'Exit Door', description: 'The way out. Heavily guarded.' },
        monster_group: {
          name:        'Windego Den',
          description: 'Bones. So many bones. Something vast and wrong unfolds itself from the darkness.',
          difficulty:   5,
          monsters:     [{ name: 'Windego', hp: 30, attack: 8, defense: 17, xp_reward: 500, description: 'It was once human. That was a long time ago.' }],
        },
        cleared: false,
      }],
    };
  }

  function renderTileHand() {
    let html = '';
    $.each(state.tileHand, function (idx, tile) {
      const icon     = tile.isExit ? '🚪' : (TILE_ICONS[tile.type.name] || '❓');
      const bldgCount = tile.buildings ? tile.buildings.length : 0;
      const isExit   = tile.isExit;

      html += '<div class="tile-hand-card' + (isExit ? ' exit-tile' : '') + '" data-hand-idx="' + idx + '">' +
              (isExit ? '<div class="exit-badge">🚪 EXIT TILE</div>' : '') +
              '<span class="tile-hand-card-icon">' + icon + '</span>' +
              '<div class="tile-hand-card-name">' + tile.type.name + '</div>' +
              '<div class="tile-hand-card-info">' +
                'Danger: ' + '☠'.repeat(tile.type.danger) + '<br>' +
                bldgCount + ' building' + (bldgCount !== 1 ? 's' : '') +
              '</div>' +
              '<p style="font-size:11px;color:var(--muted);font-style:italic">' + tile.type.description + '</p>' +
              '<button class="btn-primary" style="width:100%;margin-top:8px">SELECT →</button>' +
              '</div>';
    });
    $('#tile-hand-cards').html(html);
    $('#tile-hand').removeClass('hidden');

    $('#tile-hand-cards').off('click', '.tile-hand-card').on('click', '.tile-hand-card', function () {
      const idx = parseInt($(this).data('hand-idx'), 10);
      placeTile(state.tileHand[idx]);
    });
  }

  function placeTile(tile) {
    // Place the tile on the map
    const mapIdx = state.placedTiles.length;
    if (tile.isExit) {
      state.exitTileIdx = mapIdx;
    }
    state.placedTiles.push(tile);

    $('#tile-hand').addClass('hidden');
    state.tileHand = [];

    log('Placed: ' + tile.type.name + (tile.isExit ? ' 🚪 EXIT TILE' : '') + ' (position ' + (mapIdx + 1) + '/25)', 'success');
    renderFogMap();
    hideTilePanel();

    // Auto-draw 2 more if map isn't full
    if (state.placedTiles.length < 25) {
      setTimeout(drawTileHand, 500);
    }
  }

  function generateClassicMap() {
    hideTilePanel();
    hideBuildingPanel();
    post(API.land, { tileCount: 9 }).done(function (data) {
      state.placedTiles = data.tiles || [];
      state.exitTileIdx = -1;
      state.clearedBuildings.clear();
      renderFogMap();
      log('Classic 9-tile map generated.', 'warning');
    });
  }

  // ── Tile Panel — building list for selected tile ───────────────────────
  function showTilePanel(tile) {
    state.currentTile = tile;
    hideBuildingPanel();

    $('#tile-panel-name').text(tile.type.name + (tile.isExit ? ' 🚪' : ''));
    $('#tile-panel-desc').text(tile.type.description || '');

    let html = '';
    $.each(tile.buildings, function (idx, bi) {
      const key     = tile.id + '::' + idx;
      const cleared = state.clearedBuildings.has(key);
      const diff    = bi.monster_group.difficulty || 1;
      html += '<div class="building-row' + (cleared ? ' cleared' : '') + '">' +
              '<div class="building-row-info">' +
                '<span class="building-name">' + bi.building.name + '</span>' +
                '<span class="building-group">' + bi.monster_group.name + '</span>' +
                '<span class="building-threat">Threat: ' + '⚡'.repeat(diff) + '</span>' +
              '</div>' +
              (cleared
                ? '<span class="cleared-badge">CLEARED</span>'
                : '<button class="btn-enter btn-sm" data-tile-id="' + tile.id + '" data-idx="' + idx + '">Enter →</button>'
              ) +
              '</div>';
    });
    $('#building-list').html(html);
    $('#tile-panel').removeClass('hidden');

    $('#building-list').off('click', '.btn-enter').on('click', '.btn-enter', function () {
      const idx    = parseInt($(this).data('idx'), 10);
      const tileID = $(this).data('tile-id');
      const t      = state.placedTiles.find(function (t) { return t.id === tileID; });
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
    const char      = activeChar();
    const charClass = char ? char.class : '';

    log('Entering ' + bi.building.name + '… ' + bi.monster_group.name + ' awaits.', 'warning');

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
    $('#bldg-leader-dialogue').text(leader_dialogue ? '"' + leader_dialogue + '"' : '');

    let html = '';
    $.each(monster_group.monsters, function (_, m) {
      html += '<div class="monster-card" data-name="' + m.name + '">' +
              '<div class="monster-card-info">' +
                '<span class="monster-name">' + m.name + '</span>' +
                '<span class="monster-desc">' + (m.description || '') + '</span>' +
              '</div>' +
              '<div class="monster-card-stats">' +
                '<span class="stat-chip">HP ' + m.hp + '</span>' +
                '<span class="stat-chip">ATK +' + m.attack + '</span>' +
                '<span class="stat-chip">DEF ' + m.defense + '</span>' +
                '<span class="stat-chip xp-chip">+' + m.xp_reward + ' XP</span>' +
              '</div>' +
              '</div>';
    });
    $('#monster-group-list').html(html);

    $('#initiative-tracker').addClass('hidden');
    $('#combat-section').addClass('hidden');
    $('#fight-section').show().html(
      '<button id="fight-btn" class="btn-primary fight-btn">⚔ Fight! (' + monster_group.monsters.length + ' enemies)</button>'
    );
    $('#fight-btn').off('click').on('click', function () {
      startCombat(monster_group.monsters);
    });

    $('#building-panel').removeClass('hidden');
    $('#building-panel')[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function hideBuildingPanel() {
    $('#building-panel').addClass('hidden');
    $('#initiative-tracker').addClass('hidden');
    hideCombatSection();
    state.encounter     = null;
    state.combatQueue   = [];
    state.activeMonster = null;
    state.firstStrike   = false;
  }

  // ── Combat + Initiative ────────────────────────────────────────────────
  function startCombat(monsters) {
    state.combatQueue = monsters.map(function (m) {
      return Object.assign({}, m, { currentHP: m.hp });
    });

    // Roll initiative for all party members + all monsters
    state.initiativeOrder = rollInitiative(state.party, state.combatQueue);
    state.initiativeTurn  = 0;

    state.firstStrike = false; // used only for Gunslinger
    $('#fight-section').hide();
    renderInitiativeTracker();
    processNextTurn();
  }

  function rollInitiative(party, monsters) {
    const order = [];

    // Party members: D20 + scouting; Gunslinger gets +10 (always first)
    party.forEach(function (char, idx) {
      if (char.hp <= 0) return; // dead party members skip
      const d20  = Math.floor(Math.random() * 20) + 1;
      const stat = char.stats ? char.stats.scouting : 0;
      const bonus = char.class === 'Gunslinger' ? 10 : 0;
      const roll  = d20 + stat + bonus;
      order.push({ type: 'character', name: char.name, idx: idx, initiative: roll });
    });

    // Monsters: D20 + attack bonus
    monsters.forEach(function (m, idx) {
      const d20 = Math.floor(Math.random() * 20) + 1;
      const roll = d20 + m.attack;
      order.push({ type: 'monster', name: m.name, idx: idx, initiative: roll });
    });

    // Sort descending (ties: characters win)
    order.sort(function (a, b) {
      if (b.initiative !== a.initiative) return b.initiative - a.initiative;
      return a.type === 'character' ? -1 : 1;
    });

    log('⚡ Initiative rolled! Order: ' + order.map(function (e) {
      return e.name + '(' + e.initiative + ')';
    }).join(', '), 'warning');

    return order;
  }

  function renderInitiativeTracker() {
    const order = state.initiativeOrder;
    if (!order.length) {
      $('#initiative-tracker').addClass('hidden');
      return;
    }
    let html = '';
    order.forEach(function (entry, i) {
      const isCurrent = i === state.initiativeTurn;
      const isMon     = entry.type === 'monster';
      // Find HP for monsters
      let hpText = '';
      if (isMon) {
        const monster = state.combatQueue.find(function (m) { return m.name === entry.name; });
        if (monster) hpText = 'HP ' + monster.currentHP + '/' + monster.hp;
      } else {
        const char = state.party[entry.idx];
        if (char) hpText = 'HP ' + char.hp + '/' + char.max_hp;
      }
      html += '<div class="initiative-entry ' + (isMon ? 'monster' : 'character') + (isCurrent ? ' current-turn' : '') + '">' +
              '<span class="initiative-roll">' + entry.initiative + '</span>' +
              '<span class="initiative-name">' + (isCurrent ? '▶ ' : '') + entry.name + '</span>' +
              '<span class="initiative-hp">' + hpText + '</span>' +
              '</div>';
    });
    $('#initiative-list').html(html);
    $('#initiative-tracker').removeClass('hidden');
  }

  function processNextTurn() {
    // Skip dead monsters (already removed from combatQueue) and dead party members
    while (state.initiativeTurn < state.initiativeOrder.length) {
      const entry = state.initiativeOrder[state.initiativeTurn];
      if (entry.type === 'character') {
        const char = state.party[entry.idx];
        if (!char || char.hp <= 0) {
          state.initiativeTurn++;
          continue;
        }
        // It's a character's turn — highlight and wait for Roll Attack button
        state.activePartyIdx = entry.idx;
        state.character = char;
        renderPartyBar();
        renderStats();
        renderInitiativeTracker();
        log('→ ' + char.name + '\'s turn (initiative ' + entry.initiative + ').', 'warning');
        return;
      } else {
        // Monster turn
        const monster = state.combatQueue.find(function (m) { return m.name === entry.name && m.currentHP > 0; });
        if (!monster) {
          // Monster already defeated — skip turn
          state.initiativeTurn++;
          continue;
        }
        state.activeMonster = monster;
        renderInitiativeTracker();
        doMonsterAttack(monster);
        return;
      }
    }

    // End of round — start next round if combat still ongoing
    if (state.combatQueue.length > 0) {
      const aliveParty = state.party.filter(function (c) { return c.hp > 0; });
      if (aliveParty.length === 0) {
        onAllPlayersDefeated();
        return;
      }
      log('--- New Round ---', 'warning');
      state.initiativeTurn = 0;
      renderInitiativeTracker();
      processNextTurn();
    } else {
      onGroupDefeated();
    }
  }

  function advanceTurn() {
    state.initiativeTurn++;
    // Wrap if past end
    if (state.initiativeTurn >= state.initiativeOrder.length) {
      const aliveMonsters = state.combatQueue.filter(function (m) { return m.currentHP > 0; });
      if (aliveMonsters.length === 0) {
        onGroupDefeated();
        return;
      }
      const aliveParty = state.party.filter(function (c) { return c.hp > 0; });
      if (aliveParty.length === 0) {
        onAllPlayersDefeated();
        return;
      }
      log('--- New Round ---', 'warning');
      state.initiativeTurn = 0;
    }
    setTimeout(processNextTurn, 600);
  }

  function doMonsterAttack(monster) {
    // Monster attacks the party member with lowest HP
    const targets = state.party.filter(function (c) { return c.hp > 0; });
    if (!targets.length) { onAllPlayersDefeated(); return; }

    targets.sort(function (a, b) { return a.hp - b.hp; });
    const target = targets[0];

    const d20   = Math.floor(Math.random() * 20) + 1;
    const total = d20 + monster.attack;
    const hit   = total >= 10;
    const isCrit = d20 === 20;

    if (hit) {
      const dmg = isCrit ? Math.max(2, monster.attack) : 1 + Math.floor(monster.attack / 3);
      takeDamage(target, dmg);
      log('💀 ' + monster.name + ' attacks ' + target.name + '! ' +
          'd20:' + d20 + '+atk:' + monster.attack + '=' + total + ' → ' +
          (isCrit ? '💥 CRIT!' : 'HIT') + ' ' + dmg + ' damage. ' +
          target.name + ' has ' + target.hp + '/' + target.max_hp + ' HP.', 'combat');

      if (target.hp <= 0) {
        log('💀 ' + target.name + ' is down!', 'combat');
        renderPartyBar();
        // Check if all party dead
        if (state.party.every(function (c) { return c.hp <= 0; })) {
          onAllPlayersDefeated();
          return;
        }
      }
    } else {
      log('✨ ' + monster.name + ' misses ' + target.name + '! (' + d20 + '+' + monster.attack + '=' + total + ' vs 10)', 'success');
    }

    renderStats();
    renderPartyBar();
    // Show combat panel for the monster we're currently facing
    showCombatPanel(state.combatQueue.find(function (m) { return m.currentHP > 0; }) || state.combatQueue[0]);
    advanceTurn();
  }

  // ── Player attack ─────────────────────────────────────────────────────
  function showCombatPanel(monster) {
    if (!monster) return;
    $('#combat-monster-name').text(monster.name);
    $('#combat-monster-desc').text(monster.description || '');
    updateMonsterHP(monster);
    $('#combat-narration').text('');
    $('#combat-roll-btn').prop('disabled', false).text('Roll Attack');
    $('#combat-flee-btn').prop('disabled', false);
    $('#combat-section').removeClass('hidden');

    // Highlight active monster card
    $('#monster-group-list .monster-card').removeClass('active');
    $('#monster-group-list .monster-card[data-name="' + monster.name + '"]').addClass('active');
    $('#combat-section')[0].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function hideCombatSection() {
    $('#combat-section').addClass('hidden');
    state.activeMonster = null;
  }

  function updateMonsterHP(monster) {
    const pct = Math.max(0, Math.round((monster.currentHP / monster.hp) * 100));
    const cls = pct > 60 ? 'hp-high' : pct > 25 ? 'hp-mid' : 'hp-low';
    $('#combat-hp-bar').css('width', pct + '%').attr('class', 'hp-fill ' + cls);
    $('#combat-hp-text').text(monster.currentHP + ' / ' + monster.hp);
  }

  function getCombatStat(char) {
    if (!char) return { stat: 3, bonus: 0, critThreshold: 20 };
    const stats = char.stats;
    const cls   = char.class;
    let stat = stats.strength, bonus = 0, critThreshold = 20;

    switch (cls) {
      case 'Gunslinger':
        stat = stats.marksmanship;
        if (state.firstStrike) { bonus = 2; state.firstStrike = false; }
        break;
      case 'Brawler':
        stat = stats.strength;
        critThreshold = 18;
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
    // The current initiative entry tells us which character acts
    const entry = state.initiativeOrder[state.initiativeTurn];
    const char  = entry && entry.type === 'character' ? state.party[entry.idx] : activeChar();
    if (!char) return;

    // Pick the first living monster to fight
    const monster = state.combatQueue.find(function (m) { return m.currentHP > 0; });
    if (!monster) { onGroupDefeated(); return; }
    state.activeMonster = monster;
    showCombatPanel(monster);

    const { stat, bonus, critThreshold } = getCombatStat(char);
    const charClass = char.class;

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

      log('[' + char.name + ' vs ' + monster.name + '] d20:' + roll.roll +
          ' +stat:' + roll.stat_value + ' +bonus:' + roll.bonus +
          ' = ' + roll.total + ' → ' + outcome.toUpperCase(), 'combat');
      log(data.narration, hit ? 'success' : 'combat');

      if (hit) {
        const isCrit = outcome === 'crit_success';
        const dmg    = isCrit ? rollPlayerDamage(true) : rollPlayerDamage(false);
        monster.currentHP = Math.max(0, monster.currentHP - dmg);
        updateMonsterHP(monster);
        log('  → ' + char.name + ' deals ' + dmg + ' damage! ' + monster.name + ' has ' + monster.currentHP + ' HP left.', 'success');

        if (monster.currentHP <= 0) {
          log('  → ' + monster.name + ' is down! 💥', 'success');
          $('#monster-group-list .monster-card[data-name="' + monster.name + '"]').addClass('defeated');
          onMonsterDefeated(char, monster);
          return;
        }
      } else {
        // Miss = monster counters this turn (minor counter-attack)
        const counterDmg = rollMonsterDamage(monster, outcome === 'crit_failure');
        takeDamage(char, counterDmg);
        log('  → Counter! ' + monster.name + ' hits ' + char.name + ' for ' + counterDmg + '. HP: ' + char.hp + '/' + char.max_hp, 'combat');
        renderPartyBar();

        if (char.hp <= 0) {
          log('💀 ' + char.name + ' is down!', 'combat');
          saveCharacter(char);
          if (state.party.every(function (c) { return c.hp <= 0; })) {
            onAllPlayersDefeated();
            return;
          }
        }
      }

      renderStats();
      $('#combat-roll-btn').prop('disabled', false).text('Roll Attack');
      // Character has taken their turn — advance initiative
      advanceTurn();
    });
  }

  function rollPlayerDamage(isCrit) {
    const d6 = function () { return Math.floor(Math.random() * 6) + 1; };
    return isCrit ? d6() + d6() : d6();
  }

  function rollMonsterDamage(monster, isCritFail) {
    return isCritFail ? Math.max(2, monster.attack) : 1 + Math.floor(monster.attack / 3);
  }

  function takeDamage(char, amount) {
    if (!char) return;
    char.hp = Math.max(0, char.hp - amount);
    renderStats();
    $('#hp-display').addClass('hp-damaged');
    setTimeout(function () { $('#hp-display').removeClass('hp-damaged'); }, 600);
  }

  function awardXP(char, amount) {
    if (!char) return;
    char.xp = (char.xp || 0) + amount;
    const xpNeeded = char.level * 100;
    if (char.xp >= xpNeeded) {
      char.xp    -= xpNeeded;
      char.level++;
      char.max_hp += 4;
      char.hp      = Math.min(char.hp + 4, char.max_hp);
      log('✨ ' + char.name + ' LEVEL UP! Now level ' + char.level + '. Max HP +4!', 'success');
    }
    saveCharacter(char);
    renderStats();
    renderPartyBar();
  }

  function onMonsterDefeated(char, monster) {
    awardXP(char, monster.xp_reward);
    log('  → +' + monster.xp_reward + ' XP to ' + char.name, 'success');

    // Remove from combat queue
    const idx = state.combatQueue.findIndex(function (m) { return m === monster; });
    if (idx !== -1) state.combatQueue.splice(idx, 1);

    // Also remove from initiative order
    state.initiativeOrder = state.initiativeOrder.filter(function (e) {
      return !(e.type === 'monster' && e.name === monster.name);
    });
    // Adjust turn index after removal
    if (state.initiativeTurn >= state.initiativeOrder.length) {
      state.initiativeTurn = 0;
    }

    if (state.combatQueue.length === 0) {
      onGroupDefeated();
      return;
    }

    $('#combat-roll-btn').prop('disabled', true).text('Next…');
    setTimeout(function () { processNextTurn(); }, 1200);
  }

  function onGroupDefeated() {
    hideCombatSection();
    $('#initiative-tracker').addClass('hidden');

    const enc = state.encounter;
    if (!enc) return;

    const key = enc.tileID + '::' + enc.buildingIdx;
    state.clearedBuildings.add(key);

    log('🏆 ' + enc.monster_group.name + ' defeated! ' + enc.building.name + ' is clear.', 'success');
    $('#fight-section').show().html('<div class="cleared-victory">🏆 CLEARED — searching for supplies…</div>');

    // Save all living party members
    state.party.forEach(function (c) { if (c.hp > 0) saveCharacter(c); });

    // Loot drop
    const char  = activeChar();
    const level = char ? char.stats.scouting : 3;
    get(API.scavenge + '?level=' + level).done(function (data) {
      const activeC = activeChar();
      const max     = activeC ? activeC.class === 'Hoarder' ? 25 : 20 : 20;
      $.each(data.found, function (_, item) {
        if (activeC && activeC.inventory.length < max) {
          activeC.inventory.push(item.name);
          log('  → Looted: ' + item.name, 'success');
        } else {
          log('  → Inventory full. Left behind: ' + item.name, 'warning');
        }
      });
      if (activeC) {
        saveCharacter(activeC);
        renderInventoryGrid(activeC);
      }
    });

    renderFogMap();
  }

  function onAllPlayersDefeated() {
    hideCombatSection();
    $('#initiative-tracker').addClass('hidden');
    log('💀 The whole party is down. You crawl away, barely alive.', 'combat');
    // Set all downed characters to 1 HP
    state.party.forEach(function (c) {
      if (c.hp <= 0) {
        c.hp = 1;
        saveCharacter(c);
      }
    });
    state.combatQueue   = [];
    state.activeMonster = null;
    renderStats();
    renderPartyBar();
    $('#fight-section').show().html('<div style="color:var(--accent);font-size:12px">The party escaped — barely.</div>');
  }

  function fleeCombat() {
    const mName = state.activeMonster ? state.activeMonster.name : 'the enemy';
    log('You flee from ' + mName + '. Not every fight is yours to win.', 'warning');
    hideCombatSection();
    $('#initiative-tracker').addClass('hidden');
    state.combatQueue      = [];
    state.activeMonster    = null;
    state.firstStrike      = false;
    state.initiativeOrder  = [];
    state.initiativeTurn   = 0;
    $('#fight-section').show().html('<div style="color:var(--accent2);font-size:12px">You fled. The building is still theirs.</div>');
  }

  // ── Scavenge ──────────────────────────────────────────────────────────
  function doScavenge() {
    const char  = activeChar();
    const level = char ? char.stats.scouting : 3;
    get(API.scavenge + '?level=' + level).done(function (data) {
      log('Scavenge (scout ' + level + '): ' + data.description);
      const max = char && char.class === 'Hoarder' ? 25 : 20;
      $.each(data.found, function (_, item) {
        if (char && char.inventory.length < max) {
          char.inventory.push(item.name);
          log('  → Found: ' + item.name, 'success');
        } else {
          log('  → Inventory full. Left behind: ' + item.name, 'warning');
        }
      });
      if (char) {
        saveCharacter(char);
        renderInventoryGrid(char);
      }
    });
  }

  // ── Riddle (Ollama AI) ────────────────────────────────────────────────
  function doRiddle() {
    log('The Sphinx regards you with dramatic, ancient patience…', 'ai');
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

  // ── Craft check (global) ──────────────────────────────────────────────
  function doCraftCheck() {
    const char = activeChar();
    if (!char || char.inventory.length === 0) {
      log('Nothing in inventory to craft with.', 'warning'); return;
    }
    const craftLevel = char.stats.crafting;
    post(API.craft, { materials: char.inventory, crafting_level: craftLevel })
      .done(function (data) {
        if (data.count === 0) {
          log('Nothing craftable with current supplies.', 'warning');
          $('#craft-results').html('<p style="color:var(--muted);font-size:12px">Nothing craftable yet.</p>').removeClass('hidden');
          return;
        }
        let html = '<p style="font-size:12px;color:var(--muted)">You can craft ' + data.count + ' item(s):</p>';
        $.each(data.craftable, function (_, item) {
          html += '<div class="craft-item">' +
                  '<strong>' + item.name + '</strong> (lvl ' + item.crafting_level + ')' +
                  (item.equippable ? ' <span style="color:var(--success);font-size:10px">[equippable]</span>' : '') +
                  '<br><span style="color:var(--muted)">' + item.description + '</span>' +
                  '<br>Needs: ' + item.materials.join(', ') +
                  '<br><button class="btn-sm craft-now-btn" data-item="' + encodeURIComponent(item.name) + '" style="margin-top:4px">Craft it!</button>' +
                  '</div>';
        });
        $('#craft-results').html(html).removeClass('hidden');
        log(data.count + ' craftable item(s) found with your supplies.', 'success');

        $('#craft-results').off('click', '.craft-now-btn').on('click', '.craft-now-btn', function () {
          const itemName = decodeURIComponent($(this).data('item'));
          doCraftItem(char, itemName);
        });
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

  function put(url, data) {
    showLoading(true);
    return $.ajax({
      url:         url,
      method:      'PUT',
      contentType: 'application/json',
      data:        JSON.stringify(data),
      dataType:    'json',
    }).fail(function () {
      // PUT errors are non-fatal — log but don't show banner
    }).always(function () { showLoading(false); });
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
