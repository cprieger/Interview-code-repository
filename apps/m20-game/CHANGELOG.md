# Changelog — M20 Escape the Dungeon

---

## 2026-03-02 — Sprint 3: Party, Inventory & Map Mechanics

### Backend

- **Character persistence** — new `PUT /api/character/:id` endpoint for partial updates (HP, XP, level, inventory, equipment, location); uses pointer fields so only supplied values are overwritten:
  - `internal/character/model.go`: added `Equipment` struct (weapon/armor/accessory slots); `MaxInventorySlots()` raised to 20 (Hoarder 25); `LevelUp()` now grants +4 MaxHP (was +2); added `RemoveFirstItem()` and `ContainsItem()` helpers.
  - `internal/character/store.go`: additive migration adds `equip_json` column; `Save()` and `Load()` updated to persist equipment JSON.

- **Crafting that works** — `POST /api/character/:id/craft` verifies crafting level, consumes all required materials, appends the crafted item, saves:
  - `internal/resources/supplies.go`: added `Equippable bool` to `CraftableItem`; set for 5 items; added `CraftableItemByName()` lookup.

- **Equipment system** — `POST /api/character/:id/equip` assigns an item to a slot (weapon/armor/accessory), requiring the item to be in inventory:
  - `internal/resources/equipment.go` (new): `EquipBonuses` map of item → stat bonuses; `EquipSlots()`, `EquippableItems()`, `IsEquippable()` helpers.

- **Drop item** — `POST /api/character/:id/item/drop` removes the first occurrence of a named item and auto-unequips it from any slot:
  - `cmd/server/main.go`: new `handleDropItem` handler.

- **Level-up endpoint** — `POST /api/character/:id/levelup` calls the existing `LevelUp()` method server-side and saves:
  - `cmd/server/main.go`: new `handleLevelUp` handler.

- **Items endpoint extended** — `GET /api/items` now also returns `equip_bonuses` and `special_groups` for client use.

- **Campy B-movie tone** — all Ollama prompts updated to "Zombies Ate My Neighbors crossed with Army of Darkness" style:
  - `internal/ai/ollama.go`: added `tonePrefix` constant injected into all 6 prompt methods; all fallback functions rewritten with matching campy humour.

### Frontend

- **Tile draw mechanic** — map starts as 5×5 fog grid; two tile cards are drawn at a time (player picks one to place); after 5 tiles placed, 25% chance one card is the Exit Tile (🚪) with a Windego Den boss:
  - `web/static/js/game.js`: `drawTileHand()`, `makeExitTile()`, `renderTileHand()`, `placeTile()`, `renderFogMap()`.
  - `web/static/index.html`: `#tile-hand`, `#tile-hand-cards`, `#draw-tile-btn`.

- **Party system** — up to 4 characters shown in a party bar with HP bars; each persisted individually via `PUT /api/character/:id`; party IDs restored from `localStorage` on reload:
  - `game.js`: `addToParty()`, `renderPartyBar()`, `savePartyIDs()`, `restoreSession()`, `saveCharacter()`, `syncCharacter()`.
  - `index.html`: `#party-bar`, `#party-slots`, `#add-party-btn`.

- **Initiative-based combat** — at start of combat every party member rolls D20 + scouting; monsters roll D20 + attack; Gunslinger gets +10 (always first); turn order displayed; monster auto-attacks lowest-HP character:
  - `game.js`: `rollInitiative()`, `renderInitiativeTracker()`, `processNextTurn()`, `advanceTurn()`, `doMonsterAttack()`.
  - `index.html`: `#initiative-tracker`, `#initiative-list`.

- **Character sheet modal** — click HP display to open full overlay with identity, 7 stats, equipment slots (with bonus preview), 20-slot inventory grid, and craftable list; equip/unequip/drop/use/craft all wired:
  - `game.js`: `openCharSheet()`, `renderCharSheet()`, `renderInventoryGrid()`, `showItemMenu()`, `doEquipItem()`, `doUnequipItem()`, `doDropItem()`, `doUseItem()`, `doCraftItem()`.
  - `index.html`: `#char-sheet-modal` and all sub-sections.

- **Inventory grid** — replaces flat list with 4-column chip grid (20 slots); equipped items show badge; empty slots show dotted border.

- **Admin dashboard** — 5 new test cards for all new endpoints (Update Character, Craft Item, Equip Item, Drop Item, Level Up); all share the character ID field from Load Character card:
  - `web/static/admin.html`, `web/static/js/admin.js`: 5 new cards, 5 new test functions, `put()` AJAX helper.

- **Style** — new CSS for party bar, tile hand cards, fog/exit tiles, initiative tracker, inventory grid, item context menu, and character sheet modal:
  - `web/static/css/style.css`.

---

## Prior sprints

See git history for Sprint 1 (core game loop) and Sprint 2 (buildings, monster groups, combat, Ollama integration).
