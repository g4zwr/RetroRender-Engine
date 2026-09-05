# RetroRender-Engine

**A Custom Realtime Raytracing Engine For Roblox**

[![Luau](https://img.shields.io/badge/Language-Luau-00000?style=for-the-badge&logo=lua&logoColor=white)](https://luau.org) [![Platform](https://img.shields.io/badge/Platform-Roblox-000000?style=for-the-badge&logo=roblox&logoColor=white)](https://www.roblox.com) [![Rendering](https://img.shields.io/badge/Rendering-Raycast_Based-000000?style=for-the-badge)](#system-architecture) [![License](https://img.shields.io/badge/License-MIT-000000?style=for-the-badge)](#license)

---

## Demonstration

**RetroRender-Engine in action**

https://github.com/user-attachments/assets/cb245e31-c2d9-46e5-ab7a-30b08db79cb2

---

## Installation & Usage

Download `SCRIPT HERE.luau` from this repo and drop it into:

```
StarterPlayer → StarterPlayerScripts
```

That's it — the moment it loads, your Camera's viewport is replaced with a fully raycast-rendered, pixelated scene rebuilt every frame from the world around you.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [System Architecture](#system-architecture)
- [Tuning & Configuration](#tuning--configuration)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)
- [License](#license)

---

## Overview

**RetroRender-Engine** is a from-scratch software raytracer for Roblox that renders the entire game world as a low-resolution, chunky-pixel image — PS1-era retro style — by casting a ray per pixel straight from the client's Camera and shading whatever it hits.

Instead of relying on Roblox's built-in renderer, it builds its own screen out of a grid of `Frame` instances, then fires a `Workspace:Raycast()` for every pixel each frame, computing sky, sun, shadows, material texture, specular highlights, and reflections entirely in Luau.

It was **inspired by [RetroRaster](https://ethanthegrand.itch.io/retroraster) by ethanthegrand**, reimagined here as its own engine with a tiled/interlaced render pipeline for performance, procedural material shading, and dynamic sky/cloud/sun simulation.

---

## Key Features

| Feature | Description |
|---|---|
| **Custom Pixel Canvas** | Builds a `Frame`-based pixel grid (`FrameEditableImage`) sized to the viewport, no `EditableImage`/`ViewportFrame` required. |
| **Per-Pixel Raycasting** | Casts a real `Workspace:Raycast()` per screen pixel, converting camera rays into shaded color values. |
| **Dynamic Sky System** | Procedural sky gradient, animated `fbm`-noise clouds, and a soft-edged sun disc with glow falloff. |
| **Real-Time Shadows** | Every hit point fires a secondary shadow ray toward the sun direction to determine occlusion. |
| **Procedural Material Shading** | Grass, wood, concrete, sand, brick, metal, and plastic each get unique noise-driven texture and specular behavior. |
| **Reflections** | Reflective materials recursively trace bounce rays up to `MAX_REFLECTION_DEPTH`. |
| **Distance Fog** | Hit colors blend into sky color based on ray travel distance for atmospheric depth. |
| **Tiled/Interlaced Rendering** | Frame is split into 6x6 tiles rendered across 6 rotating phases so the full image is never traced in a single frame — keeping frame times low. |
| **Responsive Resolution** | Automatically rebuilds the pixel grid whenever the viewport size changes. |

---

## System Architecture

```
+----------------------------+
|   Camera / Viewport Size   |
+----------------------------+
              |
              v
+----------------------------+
|   FrameEditableImage Grid  |  ---> Frame-based pixel canvas
+----------------------------+
              |
              v
+----------------------------+
|  Tiled Interlace Scheduler |  ---> Splits frame into 6x6 tiles, 6 phases
+----------------------------+
              |
              v
+----------------------------+
|     Per-Pixel Raycaster    |  ---> ViewportPointToRay -> Workspace:Raycast
+----------------------------+
              |
              v
+----------------------------+
|   Sky / Sun / Cloud Model  |  ---> fbm noise, sun disc, cloud density
+----------------------------+
              |
              v
+----------------------------+
| Material Shader & Lighting |  ---> Diffuse, ambient, shadow rays, specular
+----------------------------+
              |
              v
+----------------------------+
|   Reflection Bounce Pass   |  ---> Recursive trace up to max depth
+----------------------------+
              |
              v
+----------------------------+
|   Fog Blend & Pixel Write  |  ---> Final color -> canvas:WritePixels
+----------------------------+
```

---

## Tuning & Configuration

All tunables live as constants near the top of `SCRIPT HERE.luau`:

| Constant | Purpose |
|---|---|
| `PIXEL_SIZE` | On-screen size of each rendered pixel block (retro chunkiness). |
| `MAX_DISTANCE` | Maximum raycast travel distance before fully fogged. |
| `SHADOW_DISTANCE` | Length of the secondary shadow ray toward the sun. |
| `MAX_REFLECTION_DEPTH` | How many reflection bounces are allowed per pixel. |
| `DEFAULT_REFLECTIVITY` | Fallback reflectance for parts without explicit `Reflectance`. |
| `SUN_DIR` / `SUN_ANGULAR_SIZE` / `SUN_GLOW_SIZE` | Sun position and disc/glow shape. |
| `CLOUD_HEIGHT` / `CLOUD_SCALE` / `CLOUD_SPEED` / `CLOUD_COVERAGE` | Cloud layer height, noise scale, drift speed, and density. |
| `TILE_SIZE` / `NUM_PHASES` | Interlaced tile size and how many frames a full render is spread across. |

Lower `PIXEL_SIZE` for a sharper (but heavier) image, or raise `NUM_PHASES` / `TILE_SIZE` if you need more headroom on lower-end devices.

---

## Troubleshooting

| Issue | Likely Cause | Fix |
|---|---|---|
| Screen stays black | Script not placed in `StarterPlayerScripts` | Confirm it sits directly under `StarterPlayer → StarterPlayerScripts` |
| Low FPS / stuttering | `TILE_SIZE` too large or `PIXEL_SIZE` too small for the device | Increase `PIXEL_SIZE` or `NUM_PHASES` to spread the render load further |
| Image looks laggy/behind the world | Expected — tiled interlacing renders 1/6th of the frame at a time | Reduce `NUM_PHASES` for a fresher (but heavier) image |
| No shadows appear | Sun-facing surfaces have nothing blocking `SUN_DIR` | Confirm parts exist between the surface and the sky in that direction |
| Reflections missing on shiny parts | Part `Reflectance` is 0 and below `DEFAULT_REFLECTIVITY` threshold | Raise `DEFAULT_REFLECTIVITY` or set `Reflectance` on the part |

---

## Credits

Inspired by **[RetroRaster](https://ethanthegrand.itch.io/retroraster)** by **ethanthegrand**.

---

## License

Distributed under the MIT License. See `LICENSE` for details.
