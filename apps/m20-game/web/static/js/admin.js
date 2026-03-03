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

}(jQuery));
