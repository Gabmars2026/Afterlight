# AFTERLIGHT — Full Game Plan (Open-World Survival-Parkour)

This is the master implementation plan for the full game: a Dying Light 2–inspired
open-district survival-parkour game in Godot 4. It answers the scoping prompt
directly, including the honest tradeoffs.

---

## 0. The honest answer first

**Can a solo project produce a 10-hour, photorealistic, quest-filled open world?**
No — not without years of work. Dying Light 2 took a ~500-person studio most of a
decade. Here is what the same request looks like at our scale, and what we will
actually build:

| Target | Realistic outcome here |
| --- | --- |
| 10 hours of unique content | **2–4 hours of real content**, extendable to 6–10 hours only through replayable systems (night runs, safehouse unlocks, collectibles, harder zones) — not 10 hours of hand-made story |
| AAA photorealism | **Semi-realistic**: Godot 4 Forward+ with SDFGI, volumetric fog, SSR, and CC0 PBR assets looks *good*, but not Unreal-5-demo good. Greybox now, art pass later (Phase 18) |
| Full city | **One district** of Meridian Falls (~400×400 m playable, 3 connected zones + underground), dense rather than wide |
| Branching story | **Yes, achievable** — one major faction choice + one ending choice is cheap in code, expensive only in extra content. We do it |
| Full-body first-person | **Yes, achievable** — visible arms and legs (Dying Light style). Costs animation work, planned in two steps |

**Dev-time reality (full-time equivalent):**

| Scope | Estimate |
| --- | --- |
| 1–2 hour vertical slice (Phases 1–9) | ~2–4 months solo full-time |
| The full plan below (Phases 1–20) | ~8–14 months solo full-time |
| True 10 h unique content, near-photoreal | multiple years / not solo |

**Rule when cutting scope:** cut *width* (map size, quest count), never *feel*
(movement, audio, combat responsiveness). A small dense district that feels great
beats a big empty one.

---

## 1. Project scope

**The Quarter** — one district of Meridian Falls, 3 connected surface zones + underground:

- **Old Market** (start zone): low-rise shops, dense alleys, tutorial parkour, first safehouse
- **The Heights**: mid/high-rise apartments, rooftop traversal, faction A territory
- **Terminal Yards**: warehouses, cranes, rail yard, faction B territory, endgame area
- **Undercity**: sewers + metro connecting all three (dark = dangerous at all hours)

**Content/hours budget (honest math, ~4–6 h core playthrough):**

| Content | Hours |
| --- | --- |
| Main quest (12–15 missions, 1 major branch) | ~2.5 h |
| Side quests (8–10: fetch, clear-infested, rescue/escort, safehouse) | ~1.5 h |
| Safehouses (6) + collectibles + optional areas | ~1 h |
| Travel/exploration/combat friction | ~1 h |
| Night runs / replay / hard zones (systemic, optional) | +2–4 h |

## 2. Quest system (Phase 9)

- **Data**: quests are Resources (`QuestData`: id, title, steps[], rewards, branch flags).
  Steps are typed objectives: `GOTO`, `COLLECT`, `KILL`, `INTERACT`, `ESCORT`, `SURVIVE_UNTIL`.
- **Runtime**: `QuestManager` autoload — active/completed quests, listens to global
  signals (`item_collected`, `enemy_died`, `zone_entered`, `object_interacted`), advances steps.
- **UI**: quest log (TAB), tracked quest on HUD, 3D objective markers with distance.
- **Branching**: one mid-game faction choice (Wardens vs. Free Traders) switches which
  zone hub, vendor set, and 3 late missions you get; one ending choice. Flags stored in
  `QuestManager.flags` and checked by quest preconditions — cheap, robust.
- **Side quest templates** (reused with different data — this is how real studios do it):
  fetch/retrieval, clear-the-infested-building, rescue/escort, safehouse power-on
  (find fuel → start generator → clear roof → unlock fast-travel + night refuge).

## 3. Parkour (done + Phase 4)

Already in: sprint, jump, auto-vault, mantle, slide, crouch/crawl, ladders, stamina.
Phase 4 adds: ledge-grab + shimmy, wall-jump, jump-chaining momentum bonus,
controlled drop + roll landing. State machine refactor of `player.gd`
(GROUND / AIR / SLIDE / LADDER / LEDGE / MANTLE states). No plugins needed —
CharacterBody3D + raycasts, as now.

## 4. Day/night threat cycle (Phase 6)

- `TimeManager` autoload: game clock (24 min = 24 h default), signals `night_began`/`day_began`.
- Sun: animated `DirectionalLight3D` rotation + energy/color curves; `WorldEnvironment`
  sky energy, fog color/density interpolated by time of day.
- Night: enemy spawn density ×3, faster/aggressive variants active, XP/loot bonus
  (risk/reward like Dying Light), safehouses = refuge. Ambient layers switch (already built).

## 5. Combat & enemies (Phases 3, 5, 7)

- **Guns**: done (pistol, rifle, full audio, impacts).
- **Melee (Phase 7)**: pipe/bat/machete — light (fast, low stamina) / heavy (slow,
  stagger, high stamina), durability, hit-stop + camera shake on impact.
- **Enemies (Phase 3)**: Shambler (patrol/chase/attack), Stalker (fast, flanks),
  later Screamer/Brute. `NavigationAgent3D` + state machine (IDLE/PATROL/INVESTIGATE/
  CHASE/ATTACK/STAGGER/DEAD), vision cone + hearing (gunshots/glass emit noise events).
- **Breakables (component, Phase 5)**: `Breakable` node — health, surface type,
  break sound + `CPUParticles3D` debris, replace-with-debris-mesh. Applies to glass
  (done), wooden doors (punch/melee them down), weak wall panels. Punching damages
  zombies and breakables with the same hit pipeline.

## 6. First-person body awareness (Phases 3 → 18)

- **Step 1 (with Phase 3 combat)**: simple capsule-blocked body mesh parented below the
  camera — look down and see torso/legs; procedural walk-cycle leg swing.
- **Step 2 (Phase 18)**: proper rigged body (CC0 rig), AnimationTree blending
  walk/run/jump/climb/punch; camera at neck bone, near-clip 0.05, body material
  `no_shadow_from_camera` tricks to avoid clipping artifacts.
- Arms already visible holding weapons (viewmodel), legs join in Step 1.

## 7. Visuals — the realistic ceiling (Phase 18)

- **Renderer**: Forward+; SDFGI on (dynamic GI for day/night — baked lighting won't work
  with a moving sun), volumetric fog, SSR, SSAO, TAA, filmic tonemap (partly done).
- **Materials**: PBR everywhere — albedo/normal/roughness from **Poly Haven** (CC0);
  props/buildings from **Kenney**, **Quaternius**, **itch.io CC0 packs**; decals for grime.
- **What will look good**: lighting, fog, wet streets, silhouettes, audio-driven mood.
- **What won't be AAA**: character faces, hand-animated cutscenes, foliage density,
  destruction physics. We design around strengths (mood, night, interiors).

## 8. Build order & where to cut

Systems before content (current roadmap order is already correct):
movement → combat → AI → parkour+ → district+breakables → day/night → inventory →
crafting → quests → NPCs → factions → streaming → weather → advanced AI → full
district content pass → optimization → story pass → art/audio pass → testing → release.

**Cut order if needed** (first cut = least damage):
1. Zone 3 (Terminal Yards) → 2 zones
2. Escort quests (hardest to make fun)
3. Crafting depth (keep simple recipes)
4. Rigged body Step 2 (keep Step 1)
5. Weather variety (keep rain only)
Never cut: movement feel, audio, day/night, the faction branch.

---

*This plan supersedes nothing — REQUIREMENTS.md still lists the mandatory
interactive-world/audio/camera requirements, all of which remain in force.*
