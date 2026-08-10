# Repo Layout & Handoff

> Status: draft v0.1 — 2026-08-08

## Decision: monorepo now, split at M6

`apps/m20-voxel/` lives in `Interview-code-repository` alongside `apps/m20-game/`.

**Why monorepo now:**

- The **data bridge** is the whole reason. `cmd/exportdata` writes straight to `../m20-voxel/data`. In separate repos that becomes a published artifact, a version pin, and a sync step — real overhead for zero benefit while the design is still moving.
- Canon changes in M0–M3 will be frequent and want to be **atomic across both apps**. One commit that updates a monster's Defense in Go and re-exports the JSON is much better than two PRs in two repos.
- The **Pantheon already lives at the monorepo root** (`.claude/agents/`), so agents are discoverable across both apps with no duplication.
- One clone, one `git status`.

**Why it should eventually split:**

- **The repo name is wrong for a shipping game.** "Interview-code-repository" is a fine home for a project in progress and a bad one for something on itch.io with a Venmo link. You do not want players — or an acquirer, or an employer — cloning your interview code to get the game.
- **Binary bloat.** Voxel games accumulate `.vox`, `.png`, `.wav`, `.ogg`. Git stores every version of every binary forever. A repo that's otherwise pure text will get heavy fast.
- **Different licenses and audiences.** The game ships closed under MIT-attribution obligations. The rest of the monorepo doesn't.

**Trigger to split: M6 (ship).** By then canon is stable, the export becomes a versioned artifact instead of a live path, and the game gets its own name.

## Binary assets — do this before M1

Git LFS, from the start. Retrofitting means rewriting history.

```bash
cd Interview-code-repository
git lfs install
git lfs track "apps/m20-voxel/assets/**/*.vox"
git lfs track "apps/m20-voxel/assets/**/*.png"
git lfs track "apps/m20-voxel/**/*.ogg"
git lfs track "apps/m20-voxel/**/*.wav"
git add .gitattributes && git commit -m "Track m20-voxel binary assets in LFS"
```

A `.gitattributes` with these rules is already committed at `apps/m20-voxel/.gitattributes`. **You still need to run `git lfs install` once** on your machine — the file alone doesn't do anything.

## What's ignored

`apps/m20-voxel/.gitignore` covers Godot's `.godot/` cache, exported binaries, and `*.translation`. **`data/*.json` is committed** — it's a build artifact, but committing it means the Godot project opens and runs without a Go toolchain present, which matters for anyone you hand this to.

`make export-check` guards against it going stale.

## Documentation model

Four layers, each with a different job. Keeping them separate is what stops the docs rotting.

| Layer | File(s) | Job | Changes |
|---|---|---|---|
| **Design** | `docs/00`–`docs/11` | Why the game is the way it is | Rarely, deliberately |
| **Canon** | `docs/05-m20-canon.md` + `data/*.json` | What the numbers are | Only via the Go source |
| **Working agreement** | `CLAUDE.md` | Non-negotiables every agent loads | Rarely; human-only |
| **Orientation** | `README.md`, per-directory `README.md` | How to get started and where things are | With the code |

Rules that keep this honest:

- **Design docs are versioned in their header** (`draft v0.2 — date`). Bump it when you make a real change, not a typo fix.
- **When a design decision changes, edit the doc — don't append a correction.** The doc is the current truth, and git has the history. (This already happened once: the monster roster was rewritten wholesale when the real canon showed up, not annotated.)
- **Every directory an agent owns gets a `README.md`** — matches the Pantheon's "Everything Has an Experience" standard.
- **`CLAUDE.md` is the contract.** If a rule matters enough that an agent must never break it, it belongs there, stated in one line, not buried in a design doc.

## The review checklist

`docs/REVIEW-CHECKLIST.md` is Themis's audit, run after every merge. It exists because the non-negotiables are exactly the things that are easy to violate accidentally and expensive to fix later — client-authoritative dice, drag-and-drop, `VoxelLodTerrain`, the hardcoded `>= 10` Defense bug.

## Handing this off

If someone else picks this up cold, the path is:

1. `apps/m20-voxel/README.md` — what it is, how to start
2. `docs/00-vision.md` — the game in five minutes
3. `docs/09-doc-maxamillion.md` — the framing that makes the rest cohere
4. `CLAUDE.md` — the rules
5. `docs/03-roadmap.md` — what to build next

That's about 30 minutes of reading to full context, which is the point of splitting the docs the way they're split.

## Changelog

`apps/m20-game/CHANGELOG.md` already tracks sprints for the Go game. Start `apps/m20-voxel/CHANGELOG.md` at M0 with the same format — dated entries, grouped by backend/frontend/content, naming the files touched. It's the single most useful artifact when you come back after three months away.
