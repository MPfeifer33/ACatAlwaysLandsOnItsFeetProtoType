# Room Template Generator

A level design tool for your Metroidvania - now with Hollow Knight-style tight camera!

## New Camera Settings

Your viewport is now **336×192 pixels** (21×12 tiles at 16px).
This matches Hollow Knight's intimate camera feel.

## Quick Start

### 1. Preview Available Templates
Open `Levels/Tools/preview_templates.gd` and run it (Ctrl+Shift+X).

### 2. Stamp a Template

1. Open your level scene
2. Select your **TileMapLayer**
3. Open `Levels/Tools/stamp_room_template.gd`
4. Change settings:
   ```gdscript
   const TEMPLATE_NAME := "flat_corridor"
   const ROOM_OFFSET := Vector2i(0, 0)
   ```
5. Run script (Ctrl+Shift+X)

## Room Size

All templates are now **21×12 tiles** = **336×192 pixels**

This is exactly your viewport size - one screen = one room.

## Available Templates

### Basic Shapes
| Template | Exits | Description |
|----------|-------|-------------|
| `flat_corridor` | Left, Right | Simple horizontal passage |
| `vertical_shaft` | Top, Bottom | Tall climbing room |
| `l_corner_left` | Right, Top | L-turn going left/up |
| `l_corner_right` | Left, Top | L-turn going right/up |
| `t_intersection` | Left, Right, Bottom | 3-way junction |
| `open_arena` | Left, Right | Combat room with platforms |

### Platforming Challenges
| Template | Exits | Description |
|----------|-------|-------------|
| `staircase_up` | Left, Top-Right | Ascending platforms |
| `floating_platforms` | Left, Right | Platforms over pit |
| `wall_jump_corridor` | Top, Bottom | Narrow wall-jump shaft |
| `pit_jump` | Left, Right | Wide pit with stepping stone |
| `climb_room` | Left, Top | Vertical climbing challenge |

### Special Rooms
| Template | Exits | Description |
|----------|-------|-------------|
| `save_room` | Left | Cozy save point (dead end) |
| `treasure_room` | Left | Item on pedestal (dead end) |
| `hub_room_3way` | Left, Right, Bottom | 3-way hub |
| `transition_corridor` | Left, Right | Short connector |
| `boss_arena` | Left | Boss fight room |

## Building a Level

Place rooms next to each other by offsetting in tiles:

```gdscript
// Room 1 at origin
const ROOM_OFFSET := Vector2i(0, 0)

// Room 2 to the right (21 tiles = 1 room width)
const ROOM_OFFSET := Vector2i(21, 0)

// Room 3 below room 1 (12 tiles = 1 room height)
const ROOM_OFFSET := Vector2i(0, 12)

// Room 4 diagonal (right and down)
const ROOM_OFFSET := Vector2i(21, 12)
```

## Existing Levels

Your existing levels use the old 1152×648 room size. You have two options:

1. **Rebuild them** with the new smaller rooms (recommended for consistency)
2. **Keep them** but they'll feel zoomed out compared to new content

## Multi-Screen Rooms

For larger areas (like boss arenas), you can:

1. Make rooms that are multiples of 21×12 (e.g., 42×12 for double-wide)
2. Just make the Room node bigger than the viewport
3. The camera will scroll within the room

## After Stamping

1. Add a **Room** node at position (offset × 16)
   - Size: 336×192 pixels (or multiples for bigger rooms)
2. Place **Player** at spawn marker
3. Add **Enemies/Items** at markers
4. Set up **Door triggers** to connect rooms
