# AI Development Workflow

> Status: draft v0.1 — 2026-08-08
> Researched August 2026. Framework landscape moves fast; re-check before committing budget.

## First: two different problems, don't conflate them

The word "orchestration" covers two unrelated things, and picking the wrong one costs weeks.

**1. Orchestrating agents inside your product.** LangGraph, CrewAI, AG2, Strands. You write code defining an agent graph that ships to users.

**2. Orchestrating agents that build your product.** Claude Code subagents, worktrees, MCP servers. Nothing ships; it's a dev workflow.

**You are asking for #2.** And the honest answer is that **#2 doesn't need a framework** — reaching for LangGraph here means building a development harness instead of building a game. That's the single most common way solo projects burn a month and produce nothing playable.

The only place #1 might apply is Doc M's narration, and you already solved that with a Go service.

## Recommendation: Claude Code is the orchestrator

**Use Claude Code subagents + git worktrees.** No framework, no harness, nothing to maintain.

A subagent is an independent Claude instance with its own context window, its own working directory, and its own tool access. Your main session is the orchestrator: it assigns work and assembles results. Built-in worktree support shipped in Claude Code v2.1.49 (Feb 2026), so each agent gets its own branch and its own checkout of the same repo — one agent's uncommitted edits can't stomp another's.

Practical ceiling as of mid-2026: **4–8 concurrent worktrees per developer**, and above that you're bottlenecked on *your review capacity*, not on Claude. For a solo hobby project, **3–5 is the honest number.**

### If you later want a scriptable pipeline

The one legitimate reason to add a framework: a **headless, repeatable** job — "regenerate all 26 monster JSON files," "run a balance pass across every stat block," "re-narrate every building entrance."

For that, use the **Claude Agent SDK**. It's the same primitives you're already using, scriptable, MCP-native with an in-process server model and lifecycle hooks. It composes with the workflow below instead of replacing it.

**Don't** introduce LangGraph or CrewAI. LangGraph owns stateful enterprise orchestration with heavy persistence and checkpointing — real strengths, none of them yours. CrewAI is fast for role-based prototyping, but its abstraction is *role-play* ("you are a senior architect"), and role-play is exactly the wrong decomposition for parallel code work. You want **file ownership**, not personas.

One consolation: all major frameworks converged on **MCP** as the tool layer in 2025–26, so tools are portable. Being wrong here is cheap to reverse.

## The toolchain

| Layer | Pick | Notes |
|---|---|---|
| **Orchestrator** | Claude Code (subagents + worktrees) | The whole answer for dev work |
| **Engine control** | A **Godot MCP server** | ~43 tools / 120+ operations: scene tree, nodes, scripts, signals, materials, run-and-read-errors |
| **Scriptable jobs** | Claude Agent SDK *(later, optional)* | Only for repeatable batch content jobs |
| **Local inference** | Ollama | Game runtime + bulk content. See below. |
| **Version control** | Git worktrees | The isolation primitive that makes parallelism safe |
| **Context** | `CLAUDE.md` + `docs/` | Already done. This is the highest-leverage thing you have. |

**On Godot MCP:** several implementations exist (`mkdevkit/godot-mcp`, `hi-godot/godot-ai`, Godot MCP Pro on the Asset Library). **Pick one and pin it.** The ecosystem shipped in 2025 and is younger than Unreal's — tool surfaces are smaller but growing. Setup is roughly 15 minutes: editor plugin, server bridge, client config, sanity test.

The killer capability is the feedback loop: the agent writes a script, **runs the project, reads the actual error**, and fixes it — without you in the middle.

## The agent split

**Split by file ownership, not by skill.** This is the decisive part. Two agents with overlapping directories will conflict at merge no matter how well you describe their roles. Two agents with disjoint directories can run all day.

The split below maps exactly onto the repo structure in `02-tech-stack.md`:

| Agent | Owns | Never touches | Model |
|---|---|---|---|
| **`gaia`** | `scenes/world/`, `scripts/world/`, generators, biomes, structures | gameplay, UI, net | Opus |
| **`tyche`** | `scenes/dice/`, `scripts/d20/`, `scripts/combat/` | terrain, net | Opus |
| **`ariadne`** | `scripts/net/`, replication, server export, scaling | content, UI | **Opus — never a local model** |
| **`pandora`** | `data/**`, monster/item/recipe JSON, the Go export script | engine code | Sonnet, or **Ollama** |
| **`hestia`** | `scenes/ui/`, `scripts/ui/`, InputMap, controller | simulation | Sonnet |
| **`daedalus`** | `assets/` — `.vox`, textures, palette, gen scripts | engine code, data | Sonnet |
| **`themis`** | *(read-only audit)* | — | Opus |

These are Pantheon members, matching the monorepo's existing convention in `.claude/agents/`. Gaia 🌍 the earth, Tyche 🎲 fortune, Ariadne 🧵 the thread that connects, Pandora 🏺 who lets the monsters out, Hestia 🔥 the hearth, Daedalus 🛠️ the craftsman. Themis ⚖️ already exists and takes the review role.

Shared files — `project.godot`, autoloads, `CLAUDE.md` — are **yours alone**. Agents propose changes; you apply them. That's the one place conflicts are guaranteed, so take it off the table.

Themis runs *after* merges, read-only, checking the non-negotiables in `CLAUDE.md`: is anything client-authoritative? did a dice result get computed client-side? did drag-and-drop sneak into a UI? is `Monster.Defense` actually being used?

### Where they live

Already committed at the **monorepo root** — `.claude/agents/{gaia,tyche,ariadne,pandora,hestia,daedalus}.md` — alongside the existing Pantheon, so they're discoverable from anywhere in the repo.

Each has frontmatter (`name`, `description`, `tools`, `model`) then the brief: what it owns, what it must never touch, and which `docs/` file to read first.

The existing Pantheon covers the rest — **Agon** (gameplay feel), **Atlas** (roadmap), **Themis** (review and tests), **Prometheus** (CI/deploy), **Hades** (security), **Hephaestus** (the Go side).

## Which milestones parallelize

Not all of them, and forcing it is counterproductive.

| Milestone | Agents | Why |
|---|:--:|---|
| **M0** — spike | **1** | Serial by nature. You're finding out if the stack works. |
| **M0.1** — data export | 1 | `pandora` alone. Small, self-contained, unblocks everything. |
| **M1** — cozy half | **3** | `gaia` + `hestia` + `pandora` in parallel. Cleanly disjoint. |
| **M2** — dice ⭐ | **1** | **Do not parallelize.** This is a *feel* problem and needs your hands on a controller, not throughput. |
| **M3** — night half | 2–3 | `pandora` (stat blocks, groups) ∥ `tyche` (combat) ∥ `gaia` (spawning) |
| **M4** — multiplayer | **1** | **Do not parallelize.** `ariadne` alone, everyone else paused. Concurrent edits during a netcode refactor is how you get a week of ghost bugs. |
| **M5** — scaling & content | **4–5** | Peak parallelism. Mostly independent content work. |
| **M6** — ship | 2 | `hestia` (menus, settings) ∥ `pandora` (store pages, trailer assets) |

The pattern: **parallelize breadth, serialize depth.** Content and polish fan out beautifully. Feel and architecture don't.

## Ollama's real job

You already run Ollama for Doc M. Two honest lanes for it, and one place it shouldn't go.

### ✅ Lane 1 — the game runtime (already doing this)

Doc M's voice. Keep the model **small and fast** — `llama3.2:1b` or a 3B. Latency matters more than prose quality for barks, and you have fallbacks. Don't over-model this.

### ✅ Lane 2 — bulk content drafting

This is the underused one. You need **26 monster stat blocks**, group descriptions, item flavor text, Doc M's canned fallback lines, biome descriptions. That work is high-volume, low-stakes, and schema-constrained — exactly what a local model is good at, and it's **free and unlimited**, which matters when you're doing five passes over flavor text.

Give it the JSON schema and canon docs, generate in bulk, then have `pandora` (a real model) review and you approve. Local drafts, frontier edits.

**Model picks (Aug 2026):**

| Model | VRAM | Note |
|---|---|---|
| `qwen3-coder-next` | ~16GB | Best local coder. ~70% SWE-Bench from only 3B active params of 80B. |
| `qwen3-coder:30b` | 24GB | 256K context at small-model speed |
| `devstral:24b` | 24GB | 46.8% SWE-Bench Verified; strongest at multi-file agentic work |
| `gpt-oss:20b` | 16GB | Solid 16GB pick |
| `llama3.2:1b` | tiny | **Keep for game runtime.** Fast > smart for barks. |

### ❌ Where not to use it

**Netcode, replication, authority, or the dice roll pipeline.** Even the best local model at ~46–70% SWE-Bench fails a third to half the time on real multi-file tasks. In content that's a wasted generation you regenerate for free. In netcode it's a desync you debug for two days. The economics invert completely.

Rule: **local models for things that are cheap to be wrong about.**

## The loop in practice

1. **Pick a milestone.** Read its section in `03-roadmap.md`.
2. **Decide the agent count** from the table above. Default to fewer.
3. **Spawn each agent in its own worktree** with a brief naming its owned directories and its doc.
4. **Let them run.** Don't supervise mid-flight; that defeats the purpose.
5. **Review and merge one at a time.** You are the bottleneck and that's correct.
6. **Run Themis** against the merged result on the `CLAUDE.md` non-negotiables.
7. **Play the build.** Every milestone ends playable — if you can't play it, the milestone isn't done.

## Token discipline

Ten parallel subagents cost roughly ten times the tokens of one agent for the same wall-clock time. Parallelism buys *time*, not efficiency.

So:

- **Parallelize when the work is genuinely independent**, not to feel productive.
- **Sonnet for content and UI**, Opus for architecture, netcode, and dice.
- **Ollama for bulk drafting** — free, unlimited, and good enough for flavor text.
- Your `docs/` are the cheapest optimization available: a well-scoped agent reading one doc beats a vague agent exploring the whole repo.

## What not to do

- ❌ Build an orchestration harness before you have a playable build.
- ❌ Adopt LangGraph or CrewAI for dev workflow. Wrong problem.
- ❌ Give two agents overlapping directories.
- ❌ Parallelize M2 (dice feel) or M4 (netcode).
- ❌ Use a local model for anything authoritative.
- ❌ Let an agent edit `project.godot` or autoloads. Those are yours.

## Sources

- [Claude Code Subagents and Multi-Agent Workflows (2026)](https://explainx.ai/blog/claude-code-subagents-multi-agent-workflows-2026) · [Claude Code Worktrees Guide 2026](https://likeone.ai/blog/claude-code-worktrees-guide-2026/) · [Git Worktrees + Claude Code playbook](https://www.developersdigest.tech/blog/git-worktrees-claude-code-parallel-agents-guide)
- [2026 AI Agent Framework Showdown](https://qubittool.com/blog/ai-agent-framework-comparison-2026) · [LangGraph vs CrewAI vs Claude Agent SDK](https://appinventiv.com/blog/multi-agent-frameworks/) · [AI Agent Framework Comparison 2026](https://nomadx.ae/ai-agent-framework-comparison-2026/)
- [mkdevkit/godot-mcp](https://github.com/mkdevkit/godot-mcp) · [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) · [Godot MCP Pro](https://godotengine.org/asset-library/asset/4961) · [Godot MCP setup with Claude Code](https://www.strayspark.studio/blog/godot-mcp-setup-claude-code-2026)
- [Best Ollama Models 2026 ranked by VRAM & SWE-Bench](https://www.morphllm.com/best-ollama-models) · [Qwen3-Coder ranked #1](https://localaimaster.com/models/best-local-ai-coding-models) · [Qwen3-Coder-Next guide](https://dev.to/sienna/qwen3-coder-next-the-complete-2026-guide-to-running-powerful-ai-coding-agents-locally-1k95)
