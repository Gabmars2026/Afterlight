# AFTERLIGHT — Mandatory Core Requirements

These are core gameplay systems, NOT optional polish. Each item lists its
status and the phase where it is (or will be) fully delivered.

## A. Fully interactive world

| Requirement | Status | Phase |
|---|---|---|
| Enterable buildings with functional interiors (doors, rooms, floors, stairwells) | Test building enterable (2 floors + roof) | 5, 15 |
| Multi-floor buildings (ground → stairs → floors → rooftop) | Test building | 5 |
| Loot containers, searchable rooms | Loot crate implemented | 7 |
| Hide/fight inside buildings, escape through windows | Breakable glass window implemented | 3, 5 |
| Climbable: ladders, stairs, fire escapes, ledges, rooftops, scaffolding | Ladder + mantle + stairs implemented | 4 |
| Jumping/parkour: run jumps, gap jumps, vault, slide, mantle, ledge grab, controlled drops | Vault + mantle + slide + gap jumps in | 4 |
| Raycast-based climb detection; only believable surfaces climbable | Implemented (vault/mantle raycasts) | 4 |
| Physical interaction: doors, windows, drawers, containers, generators, switches, elevators, ladders | Door, switch, crate, glass, ladder in | 5+ |
| Interactions have animation + sound + visual feedback | Implemented for all current interactables | ongoing |
| Buildings must NOT be fake — enterable, identifiable by design | Core rule for all city districts | 15 |
| Vertical world design: ground / parkour / underground routes | Design rule (see ARCHITECTURE.md) | 5, 15 |

## B. Immersive audio

| Requirement | Status | Phase |
|---|---|---|
| Surface-based footsteps (concrete, metal, wood, grass, +dirt/water/carpet/glass later) | 4 surfaces implemented | 2+ |
| Footsteps vary with walk/sprint/crouch; 3D positional at feet | Implemented | 1 |
| Weapon audio: per-weapon fire, mechanical, reload, empty, holster sounds | — | 2 |
| Distance-based gunshots (near loud / far echo / delay) | — | 2 |
| Surface-based bullet impacts (concrete/metal/glass/wood/water) | — | 2 |
| Enemy audio: breathing, growls, screams, footsteps, detectable by ear | — | 3 |
| Environmental ambience day/night layers | Wind loop (day) in | 6 |
| Interior reverb via audio buses (small room / warehouse / tunnel / stairwell) | Interior bus + zone implemented | 5 |
| Dynamic weather audio (rain surfaces, thunder, storm) | — | 13 |
| 3D positional sound sources; muffling behind walls/buildings (occlusion) | Interior zones in; raycast occlusion later | 5, 13 |
| Player audio: breathing (exhaustion), handling, jump/land, injury | Exhausted breathing + jump/land in | 1 |
| Sound priority system, audio virtualization (limit simultaneous sounds) | Pooled players (bounded) | 16 |
| Every major action: visual + audio feedback | Core rule | ongoing |

## C. First-person camera & controls

| Requirement | Status |
|---|---|
| True first-person camera at eye position, body awareness (hands/weapon Phase 2 viewmodel) | In (viewmodel Phase 2) |
| Mouse look: horizontal = body Y-rotation, vertical = head X-rotation, ±85° clamp | In |
| Mouse sensitivity setting + invert Y (pause menu sliders) | In |
| Mouse captured in gameplay; ESC opens pause menu and frees mouse; recapture on resume | In |
| Smooth camera: head bob (toggle), landing dip, sprint FOV kick, shake scale setting | In |
| Adjustable FOV (60–100, default 75), smooth transitions | In |
| CTRL crouch: lower camera, slower, quieter, fits low spaces, smooth transition | In |
| CRAWL: auto-transition in very low spaces (vents, tunnels), camera near ground, slowest | In |
| Ceiling detection: cannot stand (or crouch) without room — no clipping | In |
| WASD / SHIFT sprint / SPACE jump / E interact / R reload / LMB fire / RMB aim / TAB inventory / M map / 1-5 weapons | Keys registered; combat actions wired in Phase 2 |
| Sprint: stamina drain, FOV, heavier breathing at zero stamina | In |
| Jump: gravity, air control, arc, landing detection + sound + camera dip | In |
| Control feel: no input delay, no acceleration, no accidental cursor | In |

## Final test loop (checked every phase)

Walk → run → jump → vault → mantle → climb ladder → enter building through
door → search crate → break window → escape → rooftop → gap jump → hear
footsteps change per surface → hear reverb indoors → get exhausted → hear
breathing → ESC pause → change settings → resume.
