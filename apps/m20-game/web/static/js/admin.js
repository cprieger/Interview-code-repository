/* M20 Admin Dashboard — API tester
 * Each card hits an endpoint and renders JSON output.
 * Saved character ID is shared with the game page via localStorage.
 */

(function ($) {
  'use strict';

  $(function () {
    // Restore last character ID for convenience
    const savedID = localStorage.getItem('m20_char_id');
    if (savedID) $('#load-char-id').val(savedID);

    bindTest('#test-health',            testHealth);
    bindTest('#test-tile',              testTile);
    bindTest('#test-land',              testLand);
    bindTest('#test-scavenge',          testScavenge);
    bindTest('#test-building-enter',    testBuildingEnter);
    bindTest('#test-combat-encounter',  testCombatEncounter);
    bindTest('#test-combat',            testCombat);
    bindTest('#test-riddle',            testRiddle);
    bindTest('#test-create-char',       testCreateChar);
    bindTest('#test-load-char',         testLoadChar);
    bindTest('#test-update-char',       testUpdateChar);
    bindTest('#test-craft-item',        testCraftItem);
    bindTest('#test-equip-item',        testEquipItem);
    bindTest('#test-drop-item',         testDropItem);
    bindTest('#test-levelup',           testLevelUp);
    bindTest('#test-items',             testItems);
    bindTest('#load-metrics',           loadMetrics);
  });

  function bindTest(btnSel, fn) {
    $(btnSel).on('click', fn);
  }

  function showResult(outSel, data) {
    $(outSel).text(JSON.stringify(data, null, 2));
  }

  function showErr(outSel, xhr) {
    $(outSel).text('ERROR ' + xhr.status + ': ' + xhr.responseText);
  }

  // ── Tests ─────────────────────────────────────────────────────────────

  function testHealth() {
    get('/health', function (d) { showResult('#out-health', d); }, function (x) { showErr('#out-health', x); });
  }

  function testTile() {
    get('/api/tile', function (d) { showResult('#out-tile', d); }, function (x) { showErr('#out-tile', x); });
  }

  function testLand() {
    const n = parseInt($('#tile-count').val()) || 9;
    post('/api/land', { tileCount: n },
      function (d) { showResult('#out-land', d); },
      function (x) { showErr('#out-land', x); }
    );
  }

  function testScavenge() {
    const lvl = parseInt($('#scavenge-level').val()) || 5;
    get('/api/scavenge?level=' + lvl,
      function (d) { showResult('#out-scavenge', d); },
      function (x) { showErr('#out-scavenge', x); }
    );
  }

  function testBuildingEnter() {
    const building = $('#enter-building').val() || 'Hospital';
    const cls      = $('#enter-class').val()     || 'Brawler';
    $('#test-building-enter').prop('disabled', true).text('Asking Ollama…');
    post('/api/building/enter',
      { building: building, character_class: cls },
      function (d) {
        showResult('#out-building-enter', d);
        $('#test-building-enter').prop('disabled', false).text('POST /api/building/enter');
      },
      function (x) {
        showErr('#out-building-enter', x);
        $('#test-building-enter').prop('disabled', false).text('POST /api/building/enter');
      }
    );
  }

  function testCombatEncounter() {
    const monster = $('#enc-monster').val() || 'Zombie';
    const stat    = parseInt($('#enc-stat').val())   || 5;
    const bonus   = parseInt($('#enc-bonus').val())  || 0;
    const cls     = $('#enc-class').val()            || 'Brawler';
    $('#test-combat-encounter').prop('disabled', true).text('Asking Ollama…');
    post('/api/combat/encounter',
      { monster: monster, stat: stat, bonus: bonus, character_class: cls, crit_threshold: 20 },
      function (d) {
        showResult('#out-combat-encounter', d);
        $('#test-combat-encounter').prop('disabled', false).text('POST /api/combat/encounter');
      },
      function (x) {
        showErr('#out-combat-encounter', x);
        $('#test-combat-encounter').prop('disabled', false).text('POST /api/combat/encounter');
      }
    );
  }

  function testCombat() {
    const stat  = parseInt($('#combat-stat').val())  || 5;
    const bonus = parseInt($('#combat-bonus').val()) || 0;
    post('/api/combat/roll', { stat: stat, bonus: bonus },
      function (d) { showResult('#out-combat', d); },
      function (x) { showErr('#out-combat', x); }
    );
  }

  function testRiddle() {
    $('#riddle-status').text(' (loading…)');
    get('/api/ai/riddle',
      function (d) {
        showResult('#out-riddle', d);
        $('#riddle-status').text(d.fallback ? ' [fallback]' : ' [ollama]');
      },
      function (x) {
        showErr('#out-riddle', x);
        $('#riddle-status').text(' [error]');
      }
    );
  }

  function testCreateChar() {
    const name  = $('#new-name').val() || 'Test Survivor';
    const klass = $('#new-class').val() || '';
    post('/api/character', { name: name, class: klass },
      function (d) {
        showResult('#out-create-char', d);
        localStorage.setItem('m20_char_id', d.id);
        $('#load-char-id').val(d.id);
      },
      function (x) { showErr('#out-create-char', x); }
    );
  }

  function testLoadChar() {
    const id = $('#load-char-id').val().trim();
    if (!id) { $('#out-load-char').text('Enter a character ID.'); return; }
    get('/api/character/' + id + '/sheet',
      function (d) { showResult('#out-load-char', d); },
      function (x) { showErr('#out-load-char', x); }
    );
  }

  function testItems() {
    get('/api/items',
      function (d) { showResult('#out-items', d); },
      function (x) { showErr('#out-items', x); }
    );
  }

  function charID() {
    var id = $('#load-char-id').val().trim();
    if (!id) { alert('Enter a character ID in the Load Character card first.'); }
    return id;
  }

  function testUpdateChar() {
    var id = charID(); if (!id) return;
    var payload = {};
    var hp  = parseInt($('#upd-hp').val());
    var xp  = parseInt($('#upd-xp').val());
    var loc = $('#upd-loc').val().trim();
    if (!isNaN(hp))  payload.hp  = hp;
    if (!isNaN(xp))  payload.xp  = xp;
    if (loc)         payload.location = loc;
    put('/api/character/' + id,
      payload,
      function (d) { showResult('#out-update-char', d); },
      function (x) { showErr('#out-update-char', x); }
    );
  }

  function testCraftItem() {
    var id = charID(); if (!id) return;
    var name = $('#craft-item-name').val().trim() || 'Medkit';
    post('/api/character/' + id + '/craft',
      { item_name: name },
      function (d) { showResult('#out-craft-item', d); },
      function (x) { showErr('#out-craft-item', x); }
    );
  }

  function testEquipItem() {
    var id   = charID(); if (!id) return;
    var slot = $('#equip-slot').val();
    var item = $('#equip-item-name').val().trim() || 'Reinforced Bat';
    post('/api/character/' + id + '/equip',
      { slot: slot, item: item },
      function (d) { showResult('#out-equip-item', d); },
      function (x) { showErr('#out-equip-item', x); }
    );
  }

  function testDropItem() {
    var id   = charID(); if (!id) return;
    var name = $('#drop-item-name').val().trim() || 'Bandage';
    post('/api/character/' + id + '/item/drop',
      { item_name: name },
      function (d) { showResult('#out-drop-item', d); },
      function (x) { showErr('#out-drop-item', x); }
    );
  }

  function testLevelUp() {
    var id = charID(); if (!id) return;
    post('/api/character/' + id + '/levelup',
      {},
      function (d) { showResult('#out-levelup', d); },
      function (x) { showErr('#out-levelup', x); }
    );
  }

  function loadMetrics() {
    $.get('/metrics')
      .done(function (text) { $('#raw-metrics').text(text.slice(0, 4000)); })
      .fail(function (xhr)  { $('#raw-metrics').text('Error: ' + xhr.status); });
  }

  // ── Ajax helpers ──────────────────────────────────────────────────────

  function get(url, onDone, onFail) {
    $.ajax({ url: url, method: 'GET', dataType: 'json' }).done(onDone).fail(onFail);
  }

  function post(url, data, onDone, onFail) {
    $.ajax({
      url:         url,
      method:      'POST',
      contentType: 'application/json',
      data:        JSON.stringify(data),
      dataType:    'json',
    }).done(onDone).fail(onFail);
  }

  function put(url, data, onDone, onFail) {
    $.ajax({
      url:         url,
      method:      'PUT',
      contentType: 'application/json',
      data:        JSON.stringify(data),
      dataType:    'json',
    }).done(onDone).fail(onFail);
  }

}(jQuery));
