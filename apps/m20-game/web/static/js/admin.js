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

    bindTest('#test-health',       testHealth);
    bindTest('#test-tile',         testTile);
    bindTest('#test-land',         testLand);
    bindTest('#test-scavenge',     testScavenge);
    bindTest('#test-combat',       testCombat);
    bindTest('#test-riddle',       testRiddle);
    bindTest('#test-create-char',  testCreateChar);
    bindTest('#test-load-char',    testLoadChar);
    bindTest('#test-items',        testItems);
    bindTest('#load-metrics',      loadMetrics);
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
    get('/health', data => showResult('#out-health', data), xhr => showErr('#out-health', xhr));
  }

  function testTile() {
    get('/api/tile', data => showResult('#out-tile', data), xhr => showErr('#out-tile', xhr));
  }

  function testLand() {
    const n = parseInt($('#tile-count').val()) || 9;
    post('/api/land', { tileCount: n }, data => showResult('#out-land', data), xhr => showErr('#out-land', xhr));
  }

  function testScavenge() {
    const lvl = parseInt($('#scavenge-level').val()) || 5;
    get('/api/scavenge?level=' + lvl, data => showResult('#out-scavenge', data), xhr => showErr('#out-scavenge', xhr));
  }

  function testCombat() {
    const stat  = parseInt($('#combat-stat').val()) || 5;
    const bonus = parseInt($('#combat-bonus').val()) || 0;
    post('/api/combat/roll', { stat, bonus }, data => showResult('#out-combat', data), xhr => showErr('#out-combat', xhr));
  }

  function testRiddle() {
    $('#riddle-status').text(' (loading…)');
    get('/api/ai/riddle',
      data => { showResult('#out-riddle', data); $('#riddle-status').text(data.fallback ? ' [fallback]' : ' [ollama]'); },
      xhr  => { showErr('#out-riddle', xhr); $('#riddle-status').text(' [error]'); }
    );
  }

  function testCreateChar() {
    const name  = $('#new-name').val() || 'Test Survivor';
    const klass = $('#new-class').val() || '';
    post('/api/character', { name, class: klass },
      data => {
        showResult('#out-create-char', data);
        localStorage.setItem('m20_char_id', data.id);
        $('#load-char-id').val(data.id);
      },
      xhr => showErr('#out-create-char', xhr)
    );
  }

  function testLoadChar() {
    const id = $('#load-char-id').val().trim();
    if (!id) { $('#out-load-char').text('Enter a character ID.'); return; }
    get(`/api/character/${id}/sheet`, data => showResult('#out-load-char', data), xhr => showErr('#out-load-char', xhr));
  }

  function testItems() {
    get('/api/items', data => showResult('#out-items', data), xhr => showErr('#out-items', xhr));
  }

  function loadMetrics() {
    $.get('/metrics')
      .done(text => $('#raw-metrics').text(text.slice(0, 4000)))
      .fail(xhr  => $('#raw-metrics').text('Error: ' + xhr.status));
  }

  // ── Ajax helpers ──────────────────────────────────────────────────────

  function get(url, onDone, onFail) {
    $.ajax({ url, method: 'GET', dataType: 'json' }).done(onDone).fail(onFail);
  }

  function post(url, data, onDone, onFail) {
    $.ajax({
      url,
      method: 'POST',
      contentType: 'application/json',
      data: JSON.stringify(data),
      dataType: 'json',
    }).done(onDone).fail(onFail);
  }

}(jQuery));
