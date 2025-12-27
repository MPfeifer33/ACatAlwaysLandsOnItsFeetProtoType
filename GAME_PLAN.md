# Cat Always Lands On Its Feet - Architecture & Game Plan

## Current Architecture Overview

### Scene Hierarchy
```
Main (main.tscn)
├── LevelContainer (Node2D) ─── Levels loaded here dynamically
├── Player (cat_five.tscn) ─── Persistent, never unloaded
└── UILayer (CanvasLayer) ──── Menus overlay here
```

### Autoload Singletons
| Singleton | Purpose | Status |
|-----------|---------|--------|
| GameManager | Game state, level loading, menu transitions | ✅ Solid |
| SaveManager | Save/load, respawn, powerup tracking, abilities | ✅ Solid |
| SceneManager | Level transitions with fade, entrance spawning | ✅ Integrated |

### Level Structure (Per-Level)
```
Level.tscn
├── GameCamera ─────── Camera locked to rooms
├── TileMap ────────── Level geometry
├── PlayerStart ────── Spawn point marker
├── Rooms/ ─────────── Room bounds for camera
│   ├── Room1
│   └── Room2...
├── Enemies/ ───────── Enemy instances
└── LevelConnections/ ─ Triggers to other levels
```

---

## What's Complete ✅

### Core Systems
- **GameManager/SaveManager Split** - Clean separation of concerns
- **Component Architecture** - HealthComponent, Hitbox/Hurtbox are reusable
- **Room-Based Camera** - GameCamera handles room transitions smoothly
- **Powerup Persistence** - Collected powerups tracked per save slot
- **Hospital/Checkpoint System** - Auto-saves at checkpoints
- **Level Generator** - Procedural room generation locked down
- **Full Game Loop** - Menu → New Game → Hospital → Quit → Continue ✅

### Tama (Player Controller) - COMPLETE ✅
The player controller is feature-complete for vertical slice:

**Movement:**
- ✅ Ground movement with acceleration/friction
- ✅ Variable jump height
- ✅ Coyote time (grace period after leaving ledge)
- ✅ Jump buffering
- ✅ Wall climbing with ceiling detection
- ✅ Automatic ledge grab (Nine Sols style)
- ✅ Double jump (unlockable)
- ✅ Dash (unlockable)
- ✅ Backstep dodge with i-frames

**Combat:**
- ✅ 3-hit combo with input buffering
- ✅ Frame-accurate hitbox timing (synced to animation)
- ✅ Hitstop on hit (dealing and receiving)
- ✅ Knockback on hurt
- ✅ Screen shake on damage
- ✅ Ninja star throw (tap)
- ✅ Ninja star shotgun burst (hold) with kickback
- ✅ Controller rumble support

**Polish:**
- ✅ State machine architecture
- ✅ Graceful animation fallbacks
- ✅ Landing dust particles
- ✅ Sleep Zs effect when idle
- ✅ Glitch shader integration
- ✅ Health component integration

---

## Next Priority: Enemy & Combat Content

With Tama complete, the focus shifts to **things to fight** and **places to explore**.

### Phase 1: Enemy Variety (High Priority)
The CorruptSlime exists but needs company. Each enemy type teaches the player something:

| Enemy | Behavior | Teaches Player |
|-------|----------|----------------|
| CorruptSlime ✅ | Patrol + charge on sight | Basic combat timing |
| **Ranged Enemy** | Shoots projectiles | Dodging, closing distance |
| **Flying Enemy** | Aerial movement | Vertical combat, ninja stars |
| **Shielded Enemy** | Blocks frontal attacks | Positioning, backstep usage |
| **Fast Enemy** | Quick dashes | Reaction time, combo timing |

**Action Items:**
- [ ] Create base enemy class with shared behavior (patrol, gravity, knockback)
- [ ] Ranged enemy (archer or turret style)
- [ ] Flying enemy (bat or ghost)
- [ ] Review SamuraiPanda boss - is it functional?

### Phase 2: Level Design & Flow
Currently only procedural test level exists. Need hand-crafted content:

**Zone 1: Tutorial Area**
- [ ] Safe intro room (no enemies, just platforms)
- [ ] First combat room (1-2 slimes)
- [ ] Vertical room teaching jump/wall mechanics
- [ ] First hospital checkpoint
- [ ] Mini-boss or skill gate

**Level Template Checklist:**
```
Every level needs:
├── PlayerStart (for new game / debug)
├── GameCamera
├── At least one Room (camera bounds)
├── Hospital (if checkpoint zone)
├── LevelConnections (to adjacent zones)
└── LevelEntrances (matching connection targets)
```

### Phase 3: Upgrade System
Tama has unlock flags ready - need the actual powerups:

| Ability | Unlock Flag | Pickup Location |
|---------|-------------|-----------------|
| Wall Jump | `can_wall_jump` | Early game |
| Double Jump | `can_double_jump` | Mid game |
| Dash | `can_dash` | Mid-late game |
| Shotgun Burst | `can_shotgun_burst` | Currently unlocked (gate later) |

**Action Items:**
- [ ] Create powerup pickup scene (visual + collision)
- [ ] Hook into SaveManager's existing powerup tracking
- [ ] Design where each ability unlocks (level design dependency)

### Phase 4: UI & Feedback
- [ ] Ability cooldown indicators (dash, shotgun burst)
- [ ] Health bar polish (damage flash, low health warning)
- [ ] Boss health bar
- [ ] Simple pause menu
- [ ] Death screen with retry option

---

## Combat Feel Checklist

### Complete ✅
- [x] Hitstop on hit
- [x] Screen shake on player damage
- [x] Knockback (both directions)
- [x] Attack hitbox timing synced to frames
- [x] Combo buffering
- [x] Backstep i-frames

### Still Needed
- [ ] **I-frame visuals** - Flash/transparency during invincibility
- [ ] **Hit VFX** - Spark or slash effect on enemy hit
- [ ] **Death VFX** - Enemy death poof/particles
- [ ] **Sound effects** - Attack whoosh, hit impact, damage taken

---

## Technical Debt (Low Priority)

These work but could be cleaner:

1. **Animation loop settings** - Some animations (attack2, attack3) were set to loop incorrectly
2. **Folder structure** - Could reorganize into Entities/Enemies/, Entities/Player/, etc.
3. **Event bus** - Currently using direct references; event bus would decouple systems
4. **Audio manager** - No centralized audio system yet

---

## Quick Reference: Collision Layers

| Layer | Bit | Name | Used By |
|-------|-----|------|---------|
| 1 | 1 | World | TileMap, static geometry |
| 2 | 2 | Player | Player CharacterBody2D |
| 3 | 4 | Enemy | Enemy CharacterBody2D |
| 4 | 8 | PlayerHitbox | Player attack hitbox |
| 5 | 16 | EnemyHitbox | Enemy attack hitbox |

---

## Vertical Slice Target (April 2025)

**Goal:** One complete, polished zone playable start to finish.

**Required:**
- [x] Player controller (DONE)
- [ ] 3-5 hand-crafted rooms
- [ ] 2-3 enemy types
- [ ] 1 boss fight
- [ ] 2-3 ability pickups
- [ ] Hospital checkpoint
- [ ] Basic UI (health, maybe ability icons)
- [ ] Placeholder audio

**Nice to Have:**
- [ ] NPCs with dialogue
- [ ] Shop/upgrade station
- [ ] Collectibles (golden sushi?)
- [ ] Multiple zones connected

---

## Session Notes

### December 27, 2024
- Completed 3-hit combo system with proper input buffering
- Fixed double-attack bug (same-frame input detection)
- Added backstep dodge replacing sneak (i-frames, cooldown)
- Added shotgun burst ninja star with kickback and rumble
- Fixed coyote time (was checking before move_and_slide)
- Added sleep Zs particle effect
- **Tama's controller is DONE** 🎉

### December 26, 2024
- Architecture consolidation
- GameManager/SceneManager integration
- Full game loop verified working
- Attack hitbox timing synced to animation frames
- Hitstop implemented

---

## Tomorrow's Focus

1. **I-frame visuals** - Make invincibility visible (flashing sprite)
2. **Enemy base class** - Extract common behavior from CorruptSlime
3. **Second enemy type** - Ranged or flying
4. **Hit VFX** - Simple particle on enemy damage
5. **First hand-crafted room** - Tutorial intro space

---

*Last Updated: December 27, 2024*
