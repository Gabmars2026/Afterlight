# AFTERLIGHT — Game Architecture

Original open-world first-person survival/action game built in Godot 4.x.
Inspired by the *concepts* of modern open-world survival games; all universe,
factions, locations, and mechanics are original.

## 1. Honest scope statement

| Goal | Reality in Godot |
|---|---|
| Photorealistic AAA visuals | **Option A:** PBR asset packs + HDR + SDFGI — approaches realism, needs sourced 3D assets. **Option B (current):** stylized-realistic procedural content, upgraded per phase. |
| Massive streamed city | Achievable with chunk streaming (Phase 12) |
| Parkour, combat, AI, factions, quests | Fully achievable in GDScript |
| 60 FPS mid-range PC | Achievable with LOD/MultiMesh/occlusion discipline |

We build a **playable vertical slice first** (Phase 5 milestone), then scale.

## 2. Folder structure

- `assets/` — art and audio sources: `characters/`, `weapons/`, `environments/`, `props/`, `vegetation/`, `textures/`, `materials/`, `animations/`, `audio/`, `vfx/`
- `scenes/` — composable .tscn scenes: `world/` (districts, cells), `player/`, `enemies/`, `npcs/`, `weapons/`, `missions/`, `ui/`, `buildings/`
- `scripts/` — GDScript organized by domain, mirrors scenes: `player/`, `combat/`, `enemies/`, `ai/`, `inventory/`, `crafting/`, `quests/`, `factions/`, `world/`, `weather/`, `time/`, `save/`, `ui/`, `autoload/`
- `resources/` — data-driven `Resource` files (.tres): weapon stats, items, enemy definitions, quests, dialogue, factions
- `shaders/` — custom shaders (water, wet surfaces, wind sway)
- `navigation/` — navmesh resources per world cell
- `data/` — JSON/config data (spawn tables, loot tables)
- `docs/` — this documentation

## 3. Rendering configuration

- Renderer: **Forward+** (desktop target)
- MSAA 2x + FXAA optional per settings menu
- `WorldEnvironment`: HDR sky, filmic tonemap, fog; SSAO/SSIL/SDFGI as scalable options
- Directional sun + shadow cascades tuned to ~160 m
- Materials: `StandardMaterial3D` PBR (albedo/normal/roughness/metallic/AO)
- Expensive vs practical: SDFGI ↔ ambient sky light; volumetric fog ↔ depth fog; per-light shadows ↔ few shadow-casting lights

## 4. Core architecture principles

1. **No god scene.** The world is composed of independent cells/scenes loaded on demand.
2. **Components over inheritance.** Player = CharacterBody3D + component nodes (camera, stamina, interaction, footsteps…). Enemies share AI components.
3. **Signals up, calls down.** Children never hard-reference the world.
4. **Resources for data.** Weapons, items, quests, recipes = `Resource` classes, editable without touching code.
5. **Autoload singletons only for true globals:** `GameState`, `SaveManager`, `TimeManager`, `WeatherManager`, `QuestManager`, `FactionManager`, `AudioDirector`.

## 5. System architectures (summary)

- **Player** (`scripts/player/`) — implemented Phase 1: `player.gd` orchestrator + `camera_controller.gd`, `stamina_controller.gd`, `interaction_controller.gd`, `footstep_controller.gd`. Parkour controller added Phase 4 (raycast ledge/vault detection → mantle states).
- **Combat** (`scripts/combat/`) — Phase 2: `WeaponResource` (damage, speed, durability, type), hitbox/hurtbox areas, melee arcs via ShapeCast3D, ranged hitscan/projectile, damage numbers, limb multipliers, knockback/stagger meters.
- **Enemy AI** (`scripts/ai/`) — Phase 3+: state machine (IDLE/PATROL/INVESTIGATE/ALERT/CHASE/ATTACK/SEARCH/FLEE/DEAD), NavigationAgent3D pathing, vision cone raycasts + hearing events bus, group alerts, last-known-position search. Enemy archetypes (Shambler, Stalker, Screamer, Brute, Climber, Night Hunter, Scavenger, Remnant Soldier) = one base scene + `EnemyResource` stats + behavior flags.
- **Day/Night** (`scripts/time/`) — Phase 6: `TimeManager` autoload drives sun rotation, sky energy, enemy spawn tables, NPC schedules. 24-min real time = 24-h game day (configurable).
- **Weather** (`scripts/weather/`) — Phase 13: state machine (clear/cloudy/rain/storm/fog/wind) blending WorldEnvironment params, GPUParticles rain, wet-surface shader parameter, audio beds.
- **Survival** — hunger/hydration/infection as slow pressure, never < 60-sec interruptions; buffs from food/medicine.
- **Inventory** (`scripts/inventory/`) — Phase 7: slot-based, `ItemResource` (id, name, icon, weight, stack, rarity, category), equipment slots, quick-wheel.
- **Crafting** (`scripts/crafting/`) — Phase 8: `RecipeResource` (inputs, time, result, skill gate).
- **RPG progression** — XP per activity; skill trees (Parkour/Combat/Survival) as `SkillResource` graphs.
- **Factions** (`scripts/factions/`) — Phase 11: `FactionResource` (Wardens, Free Traders, Ash Collective, Remnant), reputation ladders, territory ownership per district, mission gating.
- **Quests** (`scripts/quests/`) — Phase 9: `QuestResource` → ordered `ObjectiveResource[]` (reach/collect/defend/interact/escort) → `RewardResource`. QuestManager tracks state, saves progress.
- **NPCs** (`scripts/npcs/`) — Phase 10: schedule resource (home/work/curfew), needs, flee behavior, barks.
- **Save** (`scripts/save/`) — Phase 5 slice: JSON snapshot (player, time, weather, quests, factions, world flags, NPC/enemy states in active cells) via `SaveManager` autoload.
- **World streaming** (`scripts/world/`) — Phase 12: city divided into `Cell_XX_YY` scenes (~100 m). `WorldStreamer` loads 3×3 around player with `ResourceLoader.load_threaded_request`, unloads beyond radius, pools enemies/props. LOD via visibility ranges; vegetation/debris via MultiMesh.

## 6. The city (original setting)

**Meridian Falls** — 12 districts: Old Downtown, Financial District, Industrial Zone, Residential Blocks, University District, Old Town, Harbor, Suburbs, Hospital District, Underground Metro, Quarantine Zone, Forested Outskirts. Each district = unique palette, enemy mix, faction influence, difficulty band, loot table.

## 7. Asset pipeline

Blender → UV → texture (Substance/ArmorPaint/CC0 PBR libraries like ambientCG/Poly Haven) → glTF → Godot import → material check → LOD meshes → collision simplification. Budgets: hero props ≤ 15k tris, buildings ≤ 30k with 3 LODs, characters ≤ 40k; textures 2k max (1k typical); collision = primitive shapes wherever possible. Only CC0/CC-BY or self-made assets.

## 8. Performance strategy

Draw calls < 2500 via MultiMesh + mesh merging; shadow casters limited; physics ticks 60 Hz with sleeping bodies; AI LOD (distant enemies think at 2 Hz, animate off-screen never); navigation baked per cell; texture channel packing; scalability presets LOW→ULTRA exposing resolution scale, shadows, view distance, foliage density, SSAO, GI, AA.

## 9. Development roadmap

See `ROADMAP.md`. Every phase ends with a playable build pushed to GitHub.
