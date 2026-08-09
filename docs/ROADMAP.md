# AFTERLIGHT — Development Roadmap

Each phase produces a playable build. Say **NEXT** to advance.
Full scope, hour budget, and honest tradeoffs: see `GAME_PLAN.md`.

- [x] **PHASE 1 — Player movement** — walk, sprint, crouch, slide, jump, gravity, stamina, head bob, footsteps, landing effects, interaction raycast, greybox test course, HUD (stamina/prompt/FPS)
- [x] **PHASE 2 — Basic combat** — pistol + automatic rifle with viewmodel, per-weapon fire sounds, reload/empty/equip audio, shell casings, recoil, muzzle flash, surface-based bullet impacts (sound + particles), weapon switching, aim zoom, training dummies, 3-floor apartment block with interior stairs/balcony/fire escape/rooftop, climbable cars, echo tunnel, generator prop, bird ambience (melee weapon moved to Phase 7 with inventory)
- [x] **PHASE 3 — Basic enemy AI** — Shambler (slow, tough) + Stalker (fast, keen-eyed) with patrol/investigate/chase/attack states, baked navigation mesh, vision cone + line-of-sight checks, hearing (gunshots 45 m, glass 24 m, sprinting 12 m), zombie voice audio (growls, alert scream, attack, hurt, death), stagger on hit, death + respawning spawners, player health bar, damage flash, death screen with auto-restart, first-person body v1 (look down to see your legs walk)
- [x] **PHASE 4 — Parkour** — ledge grab with shimmy left/right + climb-up/drop, wall jumps (alternate walls to climb shafts, stamina-gated), landing rolls (hold crouch to negate fall damage), fall damage on hard landings, flow speed bonus for chaining vaults/rolls/wall jumps, parkour gym practice area (wall shaft, ledge traverse, gap jump + catch, roll tower); vault/mantle/ladders from Phase 1
- [x] **PHASE 5 — Vertical slice environment (part 1)** — Old Market zone (NE): market square with 3 stalls + rubble, enterable shop (counter, shelves, lamp, window) with hidden storage room behind a cracked weak wall, two-storey house (interior stairs, upstairs window, roof ladder), 5 new loot crates; Breakable component (wooden doors, weak wall, barricade — splinter under fire, break noise alerts zombies); save/load v1 (F9/F10: position, view, health, stamina, ammo); all floating helper signs removed (SHOW_SIGNS flag); 2 new spawners contest the market. True underground/sewer section deferred to the streaming-world rebuild (Phase 12) since the flat ground plane can't be dug into yet
- [x] **PHASE 6 — Day/night system** — TimeManager (12 real min = 24 game hours), sun sweeps east-to-west with dawn/dusk horizon glow, sky/ambient/fog fade to true darkness, moonlight at night, HUD day/time clock (blue at night), night danger 20:00–06:00 (zombies +35% speed, +45% vision, respawn twice as fast), day/time persisted in save file. Visual restyle: sun-bleached desert town (sand ground, cobblestone streets, plaster/terracotta/blue buildings, warm sunlight, exposure-tuned) verified with rendered frames
- [x] **PHASE 7 — Inventory & melee** — 12-slot TAB inventory (bandages, ammo reserves, melee weapons, crafting scrap), loot crates give random supplies, reloading consumes inventory ammo, fists/pipe/bat melee with light + heavy swings, stamina cost and durability, humanoid zombie + player bodies with walking legs, stair headroom fixes (quick wheel deferred to a later polish phase)
- [x] **PHASE 8 — Crafting** — cloth/scrap/planks materials in loot, 5 recipes (bandage, pistol + rifle ammo, steel pipe, baseball bat), crafting column in the TAB inventory panel with live material availability
- [x] **PHASE 9 — Quest system** — QuestManager with typed objectives (reach/kill/collect/deliver), on-screen quest tracker with live counters, light-beam beacon over reach targets, quest progress in save file, first quest chain "The Last Signal" (tower -> defend -> scavenge -> deliver, with supply reward); side-quest templates + faction flags deferred to Phases 11/17
- [x] **PHASE 10 — NPCs** — three named survivors in the Old Market (Mara the trader, Dex the guard, Ivy the scavenger) with humanoid bodies, name tags, day wander / night go-home schedules, and E-to-talk speech bubbles with rotating hint dialogue
- [x] **PHASE 11 — Faction system** — 4 factions (Market Survivors, Wardens, Scavenger Union, the Feral), reputation -100..100 with standings (hostile/neutral/friendly/ally), rep from zombie kills (Wardens, capped) and quest completion (Survivors), named territory zones with a fading banner when you cross the border, reputation saved; deeper rep effects (prices, gated quests) land with Phase 17 story
- [x] **PHASE 12 — Open-world streaming** — 30 m cell grid streamed around the player (seeded, deterministic), one cell built per frame to avoid hitches, far cells freed, small props hidden beyond 2 rings (LOD); outskirts generate ruined shacks (with loot crates), car wrecks, rocks, debris, and zombie spawners using a straight-line nav fallback (no navmesh outside town); underground/sewer still waits for Phase 15 city build
- [x] **PHASE 13 — Weather** — clear/overcast/fog/rain/storm cycle (~2-3 min each, smooth transitions), rain particle field follows the player with looping rain audio, storms add lightning flashes + delayed thunder, fog thickens the air, sun/ambient/sky dim through TimeManager (single sky writer), wet ground gets glossy while it rains, zombies see 20% less and hear 40% less in rain; weather saved in quicksaves (save v4)
- [x] **PHASE 14 — Advanced AI** — 4 special infected: SCREAMER (pale, shrieks every 8 s and alerts every zombie within 45 m), BRUTE (1.4x tall, 320 HP, 30 dmg hits that knock the player flying, roars on aggro), CLIMBER (moss-green, leaps 1.4 m+ ledges to reach rooftop campers), NIGHT HUNTER (near-black, dormant/near-blind by day, 1.9x speed + 2.1x vision at night); pack behavior: any zombie that spots you pulls others within 12 m to investigate; placed across town districts + rare spawns in streamed outskirts
- [x] **PHASE 15 — Large city** — map grown 90x90 -> 150x150 with 4 handcrafted districts: MERIDIAN HEIGHTS (north: office tower with enterable lobby + zigzag fire escape to a roof crate, stepped climb tower, plaza with dry fountain), CANAL DISTRICT (south: water canal with 2 bridges, 2 enterable warehouses with climbable crate stacks + interior reverb), GREENROW (east: park with trees, pond, gazebo, 2 houses), ASHLINE (west: burned ruins, fallen beams, abandoned survivor camp - feral territory); plus the promised UNDERGROUND: sewer shaft in Greenrow with stairs down, 30 m tunnel, glowing fungus lighting, sludge channel, end chamber with 2 loot crates guarded by a night hunter, full Tunnel echo bus; faction map updated with 4 new territories; streamed outskirts pushed out to the new edge
- [x] **PHASE 16 — Optimization** — LOW/MEDIUM/HIGH graphics presets in the pause menu (shadows on/off + distance, render scale 0.75x on LOW, MSAA 2x on HIGH, streaming distance, rain density), choice saved to user://settings.cfg across runs; F3 performance overlay (FPS, frame ms, draw calls, objects, video memory, streamed cell count); outskirt props no longer cast shadows pass
- [x] **PHASE 17 — Story & missions** — 5-quest AFTERLIGHT campaign chaining reach/kill/collect/talk objectives across every district: The Last Signal (blue tower radio), Voices in the Static (talk to Mara, search canal warehouses, deliver planks to Dex), The Heights (clear the office tower roof, report to Ivy), Under the Park (descend the sewers, filter the water), Afterlight (gather 8 scrap, install the beacon, defend it against 10 zombies -> permanent golden light column over the city); new TALK objective type wired through NPC conversations with item hand-ins; per-quest item rewards + faction reputation swings; campaign progress saved (quest/step/kills)
- [x] **PHASE 18 — Graphics/audio final pass** — bloom/glow so the quest beacon, sewer fungus and muzzle flashes bleed light (off on LOW preset), gentle contrast/saturation grade, soft screen-edge vignette; night soundscape: crickets cross-fade in as the birds go quiet at dusk (4 s fade), and below 30 HP your own heartbeat thumps faster the closer you are to death
- [x] **PHASE 19 — Testing** — built-in self-test (`--headless -- --selftest`) with 28 checks across inventory, crafting, player damage/heal, factions, all 5 weather states, campaign quest restore (incl. old save formats), full save/load round-trip and world streaming; GitHub Actions workflow runs the suite on every push
- [x] **PHASE 20 — Release build** — Windows Desktop export preset (single self-contained x86_64 .exe with embedded game data, v1.0.0 metadata); GitHub Actions release pipeline: pushing a version tag builds the .exe with official export templates and attaches `Afterlight-windows-x86_64.zip` to a GitHub Release automatically

## Post-release patches

- **v1.16.0** — SUNSET FLATS. A residential district on a mesa north
  of downtown: main street, side lanes, streetlights, a ramp road
  down to the NEON DISTRICT, and 32 enterable houses in six pastel
  palettes - each with a door, warm windows, a lit room and furniture.

- **v1.15.0** — Open towers. All 12 downtown towers are now real
  buildings: a front door with a neon sign leads into a lit lobby
  with furniture, and switchback ramps along the back wall climb
  through 20 interior floors to the roof line.

- **v1.14.0** — San Andreas rules. All zombies removed (town, outskirts
  and city), box-car wrecks cleared, quests reworked to skip kill
  steps. Every vehicle on the map is now enterable: press E on any
  traffic car to carjack it - once stolen it stays yours.

- **v1.13.0** — Real wheels. The box-built cars are gone: your drivable
  ride is now the M.A.V.S Muscle Car, and street traffic mixes four
  real models (NightSky, Cleo V8, GT30, TRG) with proper bodies, rims
  and glass. Visuals extracted mesh-only so the game keeps its own
  driving physics; models turned to match the game's forward axis.

- **v1.12.0** — The frontier. SALT COAST: a sand shelf over the west
  dune ridge stepping down to a living ocean (drifting current, gentle
  swell) with a walkable seabed. GRAYSPINE PEAKS: four climbable
  mountains (60-120 m, two snow-capped) south of town with real
  collision - every slope stays under 45 degrees so you can walk to
  the summit. Both regions announce themselves as new territories.

- **v1.11.0** — NEON DISTRICT. A downtown plinth east of town: twelve
  glass towers 60-120 m tall with colored neon window strips, a lit
  avenue reached by the crosstown road, streetlights, a red-capped
  antenna on the tallest spire, and THE LAST CALL - a warm street-level
  bar with a counter, stools, barrels, a bartender and two regulars.
  Its own citizens and cops roam the district.

- **v1.10.0** — AI traffic. Seven painted sedans cruise fixed loops
  along both main streets, brake for pedestrians, zombies and you,
  creep through jammed junctions, and floor it in a panic when shot.

- **v1.9.0** — Living town. Civilians now stroll the streets going
  about their day, with police on patrol. Commit a crime and a gold
  WANTED star bar appears: most bystanders flee screaming for cover,
  the brave ones throw punches, and cops draw sidearms and hunt you
  until the heat cools off. Killing cops earns stars fast.

- **v1.8.0** — The castle. A medieval stone castle now towers over the
  dunes north of town (leave through the north gate, or drive). Grand
  steps lead up to a walled courtyard; inside the keep a great hall
  with a feast table starts a 30-floor climb past 50+ rooms, loot
  crates and a throne room, ending on the battlements. In the
  courtyard's north-east corner, stairs descend to a torchlit dungeon
  with prison cells - and two fire-breathing dragons guarding the
  loot. Shoot them; their fire hurts.

- **v1.7.0** — Drivable car. A running car (marked with a street sign)
  sits on the main street. Press E to get in, W/S to drive and reverse,
  A/D to steer, Space or E to hop out. It has headlights, an engine
  hum that revs with speed, and running over zombies at speed hurts
  them badly.

- **v1.6.0** — Weather. A layer of puffy clouds now drifts with the wind
  above the whole map. Every few minutes a rain shower rolls in: clouds
  darken, fog thickens, rain streaks fall around you with a pink-noise
  rain loop, and it all fades out again. Rain stays outside - under a
  roof the streaks stop and the sound goes muffled.

- **v1.5.0** — Control & combat fixes. Third-person body no longer sinks
  into the floor when crouching (posture now comes from the rig's crouch
  animations, and the body stays visible while crawling). Jumping works
  from crouch/crawl and while holding Shift or Ctrl - you stand up and
  hop. Q cycles weapons; 1/2/3 still pick directly. Headshots deal 3x
  damage so weak zombies drop to one good shot. Loot crates can hold a
  KNIGHT SWORD (55 dmg) and always include loose pistol + rifle bullets.

- **v1.4.0** — Furnished interiors. The Medieval Village pack props now
  decorate the world: apartment block gets a living room, floor-2 den
  and a floor-3 trophy wall (sword, axes, shield) with a squatter
  corner; the shop gets counter clutter, a corner table and a hanging
  lantern; the undercroft storage gets supplies; both canal warehouses
  get barrel rows, a squatter table and hanging lanterns with warm
  light; a standing sign now marks the market square. Solid props have
  auto-fitted collision.

- **v1.3.0** — Animated zombies. All five kinds now use the CC0 mannequin
  rig: Walk/Jog locomotion scaled to speed, Punch_Jab/Cross attacks,
  Hit_Chest/Hit_Head reactions (headshots read differently), Death01 on
  kill, glowing eyes bone-attached to the head. Brutes still tower via
  scale; per-kind body tint kept.

- **v1.2.0** — Real terrain. Terrain3D plugin drives 1 km² of baked desert
  heightmap: dunes rise beyond the town walls, the town slab stays flat, and
  the world streamer drops its flat ground tiles and snaps every ruin, rock,
  car wreck, crate and spawner to the dune surface. Sand/rock auto-shader.

- **v1.1.0** — animated character: replaced the hand-built blocky body with the CC0 rigged mannequin from the Animation Library pack (46 clips). Locomotion state machine (idle/walk/jog/sprint/crouch/jump) driven by velocity, pistol idle pose when armed, one-shot shoot/reload/melee actions, weapons attached to the right hand bone. Terrain3D plugin imported for a future terrain upgrade.

- **v1.0.7** — third-person weapon models: the equipped pistol/rifle/pipe now shows in the character's hands, arms raise and track the aim pitch, and the model swaps when you change weapons.

- **v1.0.6** — rebuilt the office tower fire escape: two-lane switchback staircase with turn landings and railings (the old floating zigzag planks were unreadable and partly blocked).

- **v1.0.5** — live top-down map screen on M (player arrow, objective marker, compass); game now starts in third-person view (V still toggles).

- **v1.0.4** — rewrote auto stair-stepping: raise-slide-drop method with multi-distance landing search; fixes players getting stuck at the base of stairs.

- [x] **v1.0.1** — the old quarantine wall around the town center is now breached with 7 gated openings (north to Meridian Heights, two south gates at the canal bridges, two east to Greenrow, two west into Ashline) with district signs; added a ring of 14 hazy mountains on the far horizon that frame the skyline in every direction
- [x] **v1.0.2** — all quarantine-wall gates now sit exactly on the road grid: north + south main gates on the x -2 road, second south gate on the x 31 canal road, east/west main gates on the z 10 crosstown road (plus the pond and camp breaches), so every road runs dead-center through its arch
- [x] **v1.0.3** — walk straight up any stairs or low ledge (automatic step-up, no jumping), longer floor snap so descending stairs feels glued; void safety net (falling out of the world returns you to the last solid ground); third-person view on V with a collision-aware camera boom and a redesigned smooth capsule-limb humanoid body: head, hair, jointed swinging arms and legs
