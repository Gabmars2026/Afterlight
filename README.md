# AFTERLIGHT

An original open-world first-person survival/action game built in Godot 4.x.

**Current build: v1.0.7 — your weapon is now visible in third person and tracks your aim.**

**Download:** grab `Afterlight-windows-x86_64.zip` from the [Releases page](https://github.com/Gabmars2026/Afterlight/releases) — no Godot needed, just unzip and run `Afterlight.exe`. (Or keep playing from the editor with F5 as always.)

## How to play

1. Open the project in Godot 4.x (`project.godot`)
2. Press **F5**

## Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Shift (hold) | Sprint (drains stamina) |
| Space | Jump |
| Ctrl (hold) | Crouch — keep walking into a low vent to crawl |
| Sprint + tap Ctrl | Slide |
| Sprint into a low obstacle | Auto-vault |
| Jump at a ledge | Mantle up |
| Walk into a ladder + hold W | Climb |
| Left mouse | Fire weapon |
| Right mouse (hold) | Aim |
| R | Reload |
| 1 / 2 / 3 | Switch weapon (pistol / rifle / melee) |
| Left mouse (melee out) | Light swing (costs stamina) |
| Right mouse (melee out) | Heavy swing (slow, 2.2x damage) |
| Tab | Inventory + crafting — click items to use, recipes to craft |
| E | Interact (doors, switches, crates, generator) |
| Space (mid-air at a wall) | Wall jump |
| A / D (while hanging) | Shimmy along ledge |
| Space / W (while hanging) | Climb up |
| Ctrl (while hanging) | Drop |
| Hold Ctrl before landing | Roll (no fall damage) |
| F9 | Quick save |
| F3 | Performance stats overlay |
| F10 | Quick load |
| Esc | Pause menu + settings (sensitivity, FOV, invert Y, head bob, shake) |

## The world

The floating helper signs are gone — the world is clean now (flip
`SHOW_SIGNS` in `test_zone.gd` to bring them back).

Around spawn: sprint lane with a vault obstacle, grass patch,
crawl vent, crouch tunnel, slide bar, metal scaffold to mantle, jump gaps,
stairs to a two-story building — sliding door, light switch, loot crate,
breakable glass window, ladder to the roof, and a rooftop gap jump.

New in Phase 2: a 3-floor **apartment block** (interior stairs, balcony
fire escape, roof hatch ladder, rooftop gap jump), **climbable cars**, an
**echo tunnel**, a **generator** that powers a floodlight, and a
**shooting range** with knock-down target dummies plus metal and wood
impact boards. Shoot the glass windows out.

Listen: footsteps change on concrete, metal, wood, and grass; sound gets
reverberant indoors and echoes hard in the tunnel; each weapon sounds
different, bullets hit each surface with its own sound, gunshots get
indoor reverb; your breathing gets heavy when stamina runs out.

New in Phase 5 — the **OLD MARKET** (north-east): a market square with
stalls and loot crates, a **shop** with a breakable wooden front door —
and a cracked **weak wall** inside hiding a pitch-dark storage room with
extra loot (shoot through it), plus a **two-storey house** with interior
stairs, an upstairs window, and a ladder to the roof. Wooden doors and
barricades splinter apart under gunfire, and breaking them makes noise
zombies will investigate. **F9/F10** quick save/load (position, health,
stamina, ammo).

## Documentation

- `docs/REQUIREMENTS.md` — mandatory core requirements and their status
- `docs/ARCHITECTURE.md` — full game architecture
- `docs/ROADMAP.md` — 20-phase development plan

## Credits

All code, textures, and sounds in this repository are original/generated.
