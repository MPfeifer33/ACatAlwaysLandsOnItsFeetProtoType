# Level Design Tools

Tools for building Metroidvania levels with room-based camera locking.

## Tools Overview

| Tool | Purpose |
|------|---------|
| `level_generator.gd` | Procedural level layout generator |
| `run_level_generator.gd` | EditorScript to run the generator |
| `room_templates.gd` | Pre-defined room tile layouts |
| `stamp_room_template.gd` | Stamp tile templates into TileMap |
| `preview_templates.gd` | Preview all available templates |

---

## Level Generator (NEW!)

Procedurally generates connected room layouts using a walker algorithm.

### Quick Start

1. Open your level scene
2. Open `Levels/Tools/run_level_generator.gd`
3. Adjust settings at the top:
   ```gdscript
   const SEED := 0          # 0 = random, or set specific seed
   const MIN_ROOMS := 8
   const MAX_ROOMS := 15
   const BRANCH_CHANCE := 0.3
   const TERMINAL_CHANCE := 0.2
   ```
4. Run script (Ctrl+Shift+X)

### What It Does

- Places a **start room** at origin
- Walks randomly, placing connected rooms
- Respects **connection rules** (boss rooms connect to corridors, etc.)
- Places **terminal rooms** (save, treasure, boss) at branch ends
- Outputs **Room nodes** with correct sizes and positions

### Room Types

**Corridors:**
- `corridor_h` - Horizontal (1x1)
- `corridor_v` - Vertical (1x1)
- `corridor_long_h` - Long horizontal (2x1)
- `corridor_long_v` - Long vertical (1x2)

**Corners:**
- `corner_tl`, `corner_tr`, `corner_bl`, `corner_br` (1x1 each)

**Junctions:**
- `t_junction_up/down/left/right` - T-intersections (1x1)
- `crossroads` - 4-way intersection (1x1)

**Special:**
- `start_room` - Player spawn (1x1)
- `save_room` - Save point, terminal (1x1)
- `treasure_room` - Loot room, terminal (1x1)
- `boss_room` - Boss arena, terminal (2x2)

**Challenge:**
- `arena_small` - Combat room (1x1)
- `arena_large` - Large combat (2x1)
- `vertical_shaft` - Tall climbing room (1x2)

### Connection Rules

Rooms connect based on tags:
- **Boss rooms** only connect to `corridor` or `hub` rooms
- **Save rooms** connect to `corridor`, `hub`, or `junction`
- **Treasure rooms** connect to `corridor` or `junction`

### Customizing Room Types

Edit `level_generator.gd` to add your own:

```gdscript
"my_custom_room": {
	"size": Vector2i(2, 1),           # 2 cells wide, 1 tall
	"exits": [Dir.LEFT, Dir.RIGHT],   # Door positions
	"tags": ["corridor", "custom"],   # For connection rules
	"terminal": false,                # true = dead end
	"weight": 5.0,                    # Spawn probability
},
```

---

## Room Templates (Tile Stamping)

Pre-defined 21×12 tile layouts for room interiors.

### Cell Size

- **1 grid cell = 1152×648 pixels** (camera room size)
- **Room templates = 21×12 tiles** at 16px = 336×192 pixels

Note: Templates are smaller than grid cells. You can:
1. Use multiple templates per cell
2. Scale up templates
3. Hand-edit after stamping

### Stamping a Template

1. Select your **TileMapLayer**
2. Open `stamp_room_template.gd`
3. Set template and offset:
   ```gdscript
   const TEMPLATE_NAME := "flat_corridor"
   const ROOM_OFFSET := Vector2i(0, 0)  # In tiles
   ```
4. Run (Ctrl+Shift+X)

### Available Templates

**Basic Shapes:**
`flat_corridor`, `vertical_shaft`, `l_corner_left`, `l_corner_right`, `t_intersection`, `open_arena`

**Platforming:**
`staircase_up`, `floating_platforms`, `wall_jump_corridor`, `pit_jump`, `climb_room`

**Special:**
`save_room`, `treasure_room`, `hub_room_3way`, `transition_corridor`, `boss_arena`

---

## Workflow

### Option A: Full Procedural

1. Run level generator → creates Room nodes
2. Add TileMapLayer
3. Stamp templates into each room (or hand-paint)
4. Add enemies, items, decorations

### Option B: Semi-Procedural

1. Run level generator to get a layout
2. Hand-adjust room positions/sizes
3. Design room interiors manually

### Option C: Manual with Tools

1. Use `RoomGridHelper` to plan layout visually
2. Generate Room nodes
3. Stamp templates as starting points
4. Heavy customization

---

## Camera Integration

The generator outputs rooms sized to your camera system:
- **Cell size:** 1152×648 pixels
- **Multi-cell rooms** (like 2x2 boss) automatically get larger Room nodes
- Camera locks to room bounds automatically

Your `GameCamera` at **2.75 zoom** shows ~419×236 pixels, so players see a portion of each room with the camera following within bounds.
