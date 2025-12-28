# Cooties

P2P multiplayer tutorial for Godot using [Steam Networking Sockets](https://partner.steamgames.com/doc/api/ISteamnetworkingSockets) and traditional IP/Port connections through [ENet](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

This repository is an open source [MIT licensed](LICENSE.md) tutorial to serve as an introduction for multiplayer in Godot.

**Checkout the game's [Itch.io page](https://bearlikelion.itch.io/cooties)** for downloads & releases.

## Overview

Cooties is a fast-paced infection/tag multiplayer platformer game where players compete to avoid catching cooties. One random player starts infected each round and must tag other players to spread the sickness. Non-infected players earn points for every second they are not sick. The player with the highest score after 5 rounds wins!

## Controls

- **Move Left**: A / Left Arrow
- **Move Right**: D / Right Arrow
- **Jump**: W / Space / Up Arrow
- **Double Jump**: Press jump again while airborne
- **Wall Jump**: Jump while sliding on a wall

## Features

### Gameplay
- 4 playable characters (Virtual Guy, Pink Man, Ninja Frog, Mask Dude)
- Randomly selected characters that are synchronized and persist between games
- Round-based infection tag gameplay (5 rounds by default)
- Game round state management (Waiting, Playing, RoundEnd, GameOver)
- Score system: Non-infected players earn 1 point per second
- Random player selection for initial infection each round
- Dynamic particle effects and sound for infected players
- Automatic win detection and gameplay restart

### Platformer Mechanics
- Smooth acceleration-based movement
- Double jump ability
- Wall sliding and wall jumping
- Physics interpolation for smooth multiplayer movement

### Multiplayer
- Steam-based networking using [GodotSteam's SteamMultiplayerPeer](https://godotsteam.com/howto/multiplayer_peer/)
- Authoritative server architecture
- RPC-based state synchronization
- Automatic player name fetching from Steam
- Host/join lobby system
- Graceful disconnection handling


## Technical Details

### Engine
- [Godot 4.5](https://godotengine.org/download/archive/4.5.1-stable/)
- [GodotSteam 4.17](https://godotsteam.com/getting_started/what_are_you_making/)
- Steamworks v1.63
- Staticly typed GDScript
- (Decently) commented code
- Mobile rendering backend


### Project Structure
```
cooties/
├── Assets/          # Game assets (sprites, sounds, etc.)
├── Scenes/
│   ├── Game/        # Main game scene and player spawning
│   ├── Lobby/       # Multiplayer lobby
│   ├── MainMenu/    # Main menu
│   ├── Player/      # Player character scene
│   └── UI/          # HUD, character select, scoreboard
├── Shaders/         # Shaders
└── Singletons/      # Global autoloads (Global, SteamInit)
```

## Installation

### Setup
1. Clone or Fork this repository
2. Open the project in Godot 4.5+ (with the GodotSteam module)
3. Run the project

*Steam must be running to use Steam features*

## Development

### Key Scripts
- [Scenes/Game/game.gd](./Scenes/Game/game.gd) - Main game loop, round management, infection logic
- [Scenes/Player/player.gd](./Scenes/Player/player.gd) - Player controller with platformer movement
- [Singletons/Global.gd](./Singletons/Global.gd) - Global state management and player data
- [Singletons/SteamInit.gd](./Singletons/SteamInit.gd) - Steam API initialization
- [Scenes/Lobby/lobby.gd](./Scenes/Lobby/lobby.gd) - Multiplayer lobby management
- [Scenes/UI/character_select.gd](./Scenes/UI/character_select.gd) - Character selection UI

### Contributing
I would love for you to contribute! This project is meant to teach! If you have an idea for a feature or a fix, *please* fork the repo and submit a pull request for me to review!

## Credits

Project by [Mark Arneman](https://arneman.me) <[bearlikelion](https://bearlikelion.com)>

Asset usted listed in [CREDITS.md](CREDITS.md)
