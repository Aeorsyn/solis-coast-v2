# Solis Coast v2 — Biblical UAP Cosmic Simulation

A Godot 4 (**4.7.2**) 3D cosmic sandbox and space shooter where you ascend as a **Biblical UAP (Ophanim)**—counter-rotating, eye-studded golden wheels—seeding life across a multi-universal cosmos, guiding civilizations from **Type 5 tribes to Type 1 Star-Forgers**, engaging in live AI-backed diplomacy, swallowing and re-forging planets Katamari-style, and dogfighting hostile UAP fleets above a full open-world coastal city.

## Core Features

* **Biblical UAP & Macro-Scale Growth (`scripts/uap_form.gd`):** Auto-transforms above **55m** (or **`[U]`** on demand) with 2.35x warp speed. Shatter worlds (**`[B]`**) into 460 GPU-instanced chunks/motes (2,300 pooled), hold **`[G]`** to vacuum 100% of debris up to **500% capacity (5 planets)** while scaling from **1x to 6x** with dynamic macro-camera pullback revealing the **Grand Celestial Astrolabe Superstructure**, and press **`[N]`** to cleanly expel 100% of stored mass into a new Super-World.
* **8 Planet Types & 4 Star Types (`scripts/cosmos_manager.gd`):** Terran, Desert, Ocean, Volcanic, Ringed Gas Giant, Storm Gas Giant, Ice Giant, and Cryo-World—plus a White Dwarf, Red Giant, Blue Supergiant, spinning Neutron Pulsar with polar jets, and a flyable cratered Moon.
* **Type 5 → Type 1 Civilization Evolution:** Worlds progress through Primordial Tribes, Megalithic Era, Industrial/Atomic (with Extinction Great Filter), Orbital Dyson Ring (Type 2), and **Star-Forger (Type 1, 5000+ Tech)** forging their own Artificial Star. Passive UAP flybys trigger historic Apparitions (**`[H]` Chronicle**); Tech 2000+ sparks interplanetary wars; Tech 5000+ & Faith >=70% raises orbiting Space Megaliths.
* **AI-Backed Cosmic Discourse (`scripts/planet_chat.gd`):** Respond to era-accurate contact hails (**`[Y]`/`[T]`/`[P]`**) or press **`[C]`** for live multi-turn diplomacy with each planet's leader via local `llama-server` (`127.0.0.1:8080`) with offline persona fallback.
* **Multiverse, Coalitions & Archetypal NPCs (`scripts/multiverse_net.gd`, `scripts/archetype_npcs.gd`):** Press **`[M]`** to warp to new procedural universes, scale empires from 5 to 500+ worlds with 550 horizon beacons, join Galactic Coalitions, host/join ENet multiplayer (`:7777`), and watch Prophets, Warlords, Star-Architects, and escorting Ascended Archons emerge.
* **Hostile UAP Fleet & Crisp Visuals (`scripts/abyss_manager.gd`):** Tic-Tac Interceptors, TR-3B Black Triangles, Plasma Orbs, and Seraphim Dreadnought Bosses set against a Milky Way / spiral-galaxy skybox, volumetric aurora curtains, ACES tonemapping, and 4x MSAA + FXAA. Press **`[F5]`** anytime for the street sandbox with wind-swaying nature (`scripts/nature_manager.gd`), Hellfire (`[F4]`), and RPG gear (`[I]`).

## Controls

| Action | PC | PS5 | Touch |
| :--- | :--- | :--- | :--- |
| **Move / Fly** | `WASD` + `Space`/`Ctrl` | Left Stick | Left Stick |
| **Look / Steer** | Mouse | Right Stick | Right Stick |
| **Hip-Fire / Aim Zoom** | `LMB` / Hold `RMB` | `R2` / Hold `L2` | `FIRE` / `AIM` |
| **Biblical UAP / No-Clip** | `U` / `F6` | — | Top Pills |
| **Seed / Teach / Smite** | `Z` / `X` / `V` | — | — |
| **Shatter / Siphon / Re-Forge** | `B` / Hold `G` / `N` | — | — |
| **Discourse / Hail Replies** | `C` / `Y` `T` `P` | — | `HAIL` |
| **Chronicle / Multiverse** | `H` / `M` | — | — |
| **Abyss / Hellfire / Input** | `F5` / `F4` / `CTRL` Pill | Top Pills | Top Pills |

## Key Files
* `scripts/`: `main.gd`, `uap_form.gd`, `cosmos_manager.gd`, `planet_chat.gd`, `multiverse_net.gd`, `archetype_npcs.gd`, `abyss_manager.gd`, `nature_manager.gd`, `ots_camera.gd`, `touch_hud.gd`
* `shaders/`: `deep_space_sky.gdshader`, `aurora_veil.gdshader`, `living_planet.gdshader`, `stellar_star.gdshader`, `lunar_moon.gdshader`, `foliage_wind.gdshader`

## Run & Export
* **Desktop:** `WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/$(id -u) godot --path ~/solis_coast_v2`
* **Local AI (`llama-server`):** `llama-server -m /path/to/model.gguf --port 8080 --host 127.0.0.1`
* **Android APK:** `godot --headless --path ~/solis_coast_v2 --export-debug "Android" ~/solis_coast_v2/SolisCoast_v2.apk`
