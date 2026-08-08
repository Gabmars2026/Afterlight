# AFTERLIGHT — Development Roadmap

Each phase produces a playable build. Say **NEXT** to advance.
Full scope, hour budget, and honest tradeoffs: see `GAME_PLAN.md`.

- [x] **PHASE 1 — Player movement** — walk, sprint, crouch, slide, jump, gravity, stamina, head bob, footsteps, landing effects, interaction raycast, greybox test course, HUD (stamina/prompt/FPS)
- [x] **PHASE 2 — Basic combat** — pistol + automatic rifle with viewmodel, per-weapon fire sounds, reload/empty/equip audio, shell casings, recoil, muzzle flash, surface-based bullet impacts (sound + particles), weapon switching, aim zoom, training dummies, 3-floor apartment block with interior stairs/balcony/fire escape/rooftop, climbable cars, echo tunnel, generator prop, bird ambience (melee weapon moved to Phase 7 with inventory)
- [x] **PHASE 3 — Basic enemy AI** — Shambler (slow, tough) + Stalker (fast, keen-eyed) with patrol/investigate/chase/attack states, baked navigation mesh, vision cone + line-of-sight checks, hearing (gunshots 45 m, glass 24 m, sprinting 12 m), zombie voice audio (growls, alert scream, attack, hurt, death), stagger on hit, death + respawning spawners, player health bar, damage flash, death screen with auto-restart, first-person body v1 (look down to see your legs walk)
- [x] **PHASE 4 — Parkour** — ledge grab with shimmy left/right + climb-up/drop, wall jumps (alternate walls to climb shafts, stamina-gated), landing rolls (hold crouch to negate fall damage), fall damage on hard landings, flow speed bonus for chaining vaults/rolls/wall jumps, parkour gym practice area (wall shaft, ledge traverse, gap jump + catch, roll tower); vault/mantle/ladders from Phase 1
- [x] **PHASE 5 — Vertical slice environment (part 1)** — Old Market zone (NE): market square with 3 stalls + rubble, enterable shop (counter, shelves, lamp, window) with hidden storage room behind a cracked weak wall, two-storey house (interior stairs, upstairs window, roof ladder), 5 new loot crates; Breakable component (wooden doors, weak wall, barricade — splinter under fire, break noise alerts zombies); save/load v1 (F9/F10: position, view, health, stamina, ammo); all floating helper signs removed (SHOW_SIGNS flag); 2 new spawners contest the market. True underground/sewer section deferred to the streaming-world rebuild (Phase 12) since the flat ground plane can't be dug into yet
- [ ] **PHASE 6 — Day/night system** — TimeManager, sun cycle, night danger, spawn tables
- [ ] **PHASE 7 — Inventory & melee** — slot inventory, items, equipment, quick wheel; melee weapons (pipe/bat) with light/heavy attacks, stamina cost, durability, punching
- [ ] **PHASE 8 — Crafting** — recipes, materials, crafting UI
- [ ] **PHASE 9 — Quest system** — QuestManager, typed objectives, quest log + markers, side-quest templates (fetch/clear/rescue/safehouse), faction branch flags, "The Last Signal" quest
- [ ] **PHASE 10 — NPCs** — settlement NPCs, schedules, dialogue v1
- [ ] **PHASE 11 — Faction system** — 4 factions, reputation, territory
- [ ] **PHASE 12 — Open-world streaming** — cell loading, pooling, LOD
- [ ] **PHASE 13 — Weather** — rain, storm, fog, wet surfaces
- [ ] **PHASE 14 — Advanced AI** — Screamer, Brute, Climber, Night Hunter, group behavior
- [ ] **PHASE 15 — Large city** — all districts of Meridian Falls
- [ ] **PHASE 16 — Optimization** — scalability presets, profiling pass
- [ ] **PHASE 17 — Story & missions** — main questline
- [ ] **PHASE 18 — Graphics/audio final pass**
- [ ] **PHASE 19 — Testing**
- [ ] **PHASE 20 — Release build** — exports for Windows
