# Merge Grove Art Assets

## Style Guide

- **Visual Style:** Cozy, flat 2D farm aesthetic
- **Color Palette:** Warm earth tones (greens, browns, golds) with pops of color for items
- **Format:** SVG (resolution-independent, zero compression artifacts)
- **Cell Size:** 48x48px viewBox for merge items (rendered at 44x44 in-game)
- **Portrait Size:** 128x128px
- **Farm Zone Size:** 390x400px

## Asset Manifest

### Merge Items (assets/items/)

| File | Description | Chain | Tier |
|------|-------------|-------|------|
| crops_t1.svg | Seed in soil | Crops | 1 |
| crops_t2.svg | Small sprout | Crops | 2 |
| crops_t3.svg | Bush with berries | Crops | 3 |
| crops_t4.svg | Harvest basket | Crops | 4 |
| crops_t5.svg | Golden cornucopia | Crops | 5 |
| tools_t1.svg | Twig | Tools | 1 |
| tools_t2.svg | Stick | Tools | 2 |
| tools_t3.svg | Wooden plank | Tools | 3 |
| tools_t4.svg | Wood bundle | Tools | 4 |
| tools_t5.svg | Garden fence | Tools | 5 |
| creatures_t1.svg | Egg | Creatures | 1 |
| creatures_t2.svg | Chick | Creatures | 2 |
| creatures_t3.svg | Hen | Creatures | 3 |
| creatures_t4.svg | Rooster | Creatures | 4 |
| creatures_t5.svg | Phoenix | Creatures | 5 |
| seed_pouch.svg | Seed pouch icon | - | - |

### UI Elements (assets/ui/)

| File | Description | Size |
|------|-------------|------|
| coin_icon.svg | Gold coin with star emblem | 48x48 |
| energy_icon.svg | Lightning bolt with glow | 48x48 |
| gem_icon.svg | Faceted blue gem | 48x48 |
| btn_normal.svg | Button normal state | 48x48 |
| btn_pressed.svg | Button pressed state | 48x48 |
| cell_empty.svg | Empty grid cell | 48x48 |
| cell_highlight.svg | Highlighted grid cell | 48x48 |
| panel_bg.svg | Panel background | 48x48 |

### Portraits (assets/portraits/)

| File | Description | Size |
|------|-------------|------|
| hazel.svg | Hazel - farmer character with straw hat | 128x128 |
| bramble.svg | Bramble - hedgehog with glasses | 128x128 |

### Farm Zones (assets/farm/)

| File | Description | Size |
|------|-------------|------|
| zone1_before.svg | Overgrown garden (weeds, stumps, rocks) | 390x400 |
| zone1_after.svg | Restored garden (beds, flowers, trees, fence) | 390x400 |

## Integration Notes

### Godot Import Settings
- SVGs are imported as Texture2D resources automatically
- Merge items are loaded via `ItemData.get_item_sprite_path()` and displayed in `MergeItem` nodes at 44x44px
- UI icons are referenced as ext_resources in hud.tscn
- Farm zones are referenced as ext_resources in main.tscn
- Portraits are loaded dynamically in dialog_box.gd

### File Naming Convention
- Items: `{chain}_{tier}.svg` (e.g., `crops_t3.svg`)
- UI: `{element_name}.svg` (e.g., `coin_icon.svg`)
- Portraits: `{character_name}.svg` (e.g., `hazel.svg`)
- Zones: `zone{n}_{state}.svg` (e.g., `zone1_before.svg`)

### Adding New Assets
1. Place SVG in the appropriate `assets/` subdirectory
2. For merge items: add the path to `ItemData.ITEM_DATA`
3. For UI elements: reference as ext_resource in the relevant .tscn file
4. For portraits: add the character name to the story beats in dialog_box.gd
5. For zones: add ext_resources in main.tscn and update main.gd zone logic
