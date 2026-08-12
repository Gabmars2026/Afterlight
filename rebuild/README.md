# Afterlight clean rebuild

This directory is a new, modular boot path built alongside the original game.
Nothing under `scenes/world` or `scripts/world` was deleted.

The rebuild currently provides:

- the established movement, parkour, crawling, climbing, combat and interaction controller;
- a drivable vehicle with safe exits and collision response;
- an enterable workshop with an interactive sliding door and interior props;
- separate commercial, industrial and suburban districts generated from every
  primary Kenney building GLB;
- Kenney modular roads, signs, lights, trees and construction props;
- a plaza demonstrating the existing medieval GLB prop library;
- existing textures, surface metadata, footsteps, ambience, HUD and pause menu;
- a small `rebuild_main.gd` composition root and one focused world builder.

The legacy build remains runnable at `res://scenes/world/test_zone.tscn`.
The clean build starts at `res://rebuild/rebuild_main.tscn`.

Next architectural steps should split the established player controller into
movement states, add district streaming around this asset-driven layout, and
move the workshop into a reusable authored scene.
