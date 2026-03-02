# web/static/

Static assets served directly by the Go server via `http.ServeFile`.

| File | Purpose |
|---|---|
| `index.html` | Game UI — character creation, map, combat, scavenging |
| `admin.html` | Admin dashboard — API tester, raw metrics viewer |
| `js/jquery-3.7.1.min.js` | jQuery (served locally — no CDN supply chain risk) |
| `js/game.js` | Game client logic (IIFE, jQuery, localStorage for session) |
| `js/admin.js` | Admin panel logic (API test buttons, JSON output) |
| `css/style.css` | Post-apocalyptic dark theme, mobile-first |

## Game UI features

- Character creation with class preview
- 3×3 tile map generation with danger-level color coding
- Scavenge, explore building, random combat, Sphinx riddle (Ollama)
- Inventory with crafting check
- Session persistence via `localStorage` (character ID)

## Design principles (Iris standard)

- All states designed: loading (spinner), error (banner), empty (message)
- Mobile-first CSS — action bar stacks on small screens
- `var(--accent)`, `var(--surface)` CSS custom properties throughout — theme is one edit
- `web/static/` is the only path exposed — no directory traversal
