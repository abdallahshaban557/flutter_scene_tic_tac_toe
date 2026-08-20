# 3D Animated Tic-Tac-Toe (Flutter Scene)

A 3D Tic-Tac-Toe game built with **Flutter** and
**[Flutter Scene](https://pub.dev/packages/flutter_scene)**, featuring animated
3D character pieces with unique personalities and a fun, interactive win
mechanic.

---

## 🎮 What the Game Does

This game brings classic gameplay to life with animated 3D characters and custom
game mechanics:

- **Animated 3D Characters**:
  - **Player X**: Crimson/coral character with animated cartoon eyes and
    expressive facial features.
  - **Player O**: Cyan/azure torus character with dynamic animated eyes and
    mouth.
- **Dynamic Spawn & Idle Animations**:
  - When a piece is placed, it drops onto the 3D grid with an elastic bounce
    animation.
  - Pieces have continuous idle breathing and looking animations while waiting
    on the board.
- **"Winner Eats Loser" Feast Mechanic**:
  - When a player gets three-in-a-row to win, the winning pieces celebrate.
  - Each winning character identifies and hunts down the nearest opposing piece,
    moves to its position, and **chomps / eats** it!
  - Accompanied by 3D particle bursts (crumbs) and shrinking/trembling defeat
    animations for eaten pieces.
  - After feasting, the winning characters return to their home tiles to
    celebrate victory.
- **Direct 3D Board Interaction & Mini-Map**:
  - Tap directly on the 3D board tiles via accurate 3D ray-casting / ray-plane
    intersection picking.
  - Includes a 2D interactive HUD overlay with scoreboard, turn status
    indicators, camera reset, and mini-map fallback.
- **Free Orbit Camera**:
  - Rotate, pan, and zoom around the 3D board to view the action from any angle.

---

## 🚀 Built with Flutter Scene

This project demonstrates the capabilities of **Flutter Scene**, A Flutter 3D
engine.

---

## 🛠️ Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Flutter 3.47.1+)
- Compatible on mobile, web, and Desktop!

### Installation & Run

1. **Clone the repository**:

   ```bash
   git clone https://github.com/abdallahshaban557/flutter_scene_tic_tac_toe.git
   cd flutter_scene_tic_tac_toe
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run --enable-flutter-gpu
   ```

---

## 📂 Project Structure

```text
lib/
├── game/
│   └── game_controller.dart     # Turn logic, win checking, eating pairings & state
├── scene/
│   ├── animated_piece.dart      # 3D animation states, chomp logic & particle physics
│   ├── piece_builder.dart       # PBR materials, procedural geometries & GLB loader
│   └── tic_tac_toe_scene.dart   # Flutter Scene setup, lighting, camera & 3D ray picking
├── ui/
│   └── game_overlay.dart        # 2D HUD, scoreboard, mini-map & controls
└── main.dart                    # App entrypoint and 3D SceneView container
```
