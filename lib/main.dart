import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'game/game_controller.dart';
import 'scene/tic_tac_toe_scene.dart';
import 'ui/game_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TicTacToeApp());
}

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Tic-Tac-Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE94560),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const TicTacToeGameScreen(),
    );
  }
}

class TicTacToeGameScreen extends StatefulWidget {
  const TicTacToeGameScreen({super.key});

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  final GameController _gameController = GameController();
  late final TicTacToe3DScene _gameScene;
  bool _isReady = false;
  String? _initError;
  Offset? _pointerDownPos;

  @override
  void initState() {
    super.initState();
    _gameScene = TicTacToe3DScene(gameController: _gameController);

    _gameScene.load().then((_) {
      if (mounted) {
        setState(() => _isReady = true);
      }
    }).catchError((err, st) {
      if (mounted) {
        setState(() => _initError = "$err");
      }
    });
  }

  void _handleNewGame() {
    _gameController.resetGame();
    _gameScene.resetBoard();
  }

  void _handleResetScores() {
    _gameController.resetScores();
    _gameScene.resetBoard();
  }

  void _handleResetCamera() {
    _gameScene.resetCamera();
  }

  void _handleCellTapped(int index) {
    _gameController.makeMove(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  "Failed to Initialize 3D Engine",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFE94560), Color(0xFF0F3460)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE94560).withValues(alpha: 0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "INITIALIZING 3D ENGINE",
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Compiling Shaders & Building PBR Meshes",
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 3D Viewport with 3D Ray-Picking and Orbit Camera Controls
          LayoutBuilder(
            builder: (context, constraints) {
              final viewSize = constraints.biggest;
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  _pointerDownPos = event.localPosition;
                },
                onPointerUp: (event) {
                  if (_pointerDownPos != null) {
                    final dist = (event.localPosition - _pointerDownPos!).distance;
                    // If pointer didn't drag more than 10 pixels, treat as a direct 3D board tap
                    if (dist < 10) {
                      final pickedCell = _gameScene.pickCellAtScreenPoint(
                        event.localPosition,
                        viewSize,
                      );
                      if (pickedCell != null) {
                        _handleCellTapped(pickedCell);
                      }
                    }
                  }
                  _pointerDownPos = null;
                },
                child: _gameScene.orbitController != null
                    ? CameraControls(
                        controller: _gameScene.orbitController!,
                        child: SceneView(
                          _gameScene.scene,
                          onTick: (elapsed, dt) => _gameScene.tick(dt),
                        ),
                      )
                    : SceneView(
                        _gameScene.scene,
                        onTick: (elapsed, dt) => _gameScene.tick(dt),
                      ),
              );
            },
          ),

          // 2. Interactive UI Overlay (Header, Scoreboard, Status, Controls, Mini-map)
          ListenableBuilder(
            listenable: _gameController,
            builder: (context, _) {
              return GameOverlay(
                controller: _gameController,
                onNewGame: _handleNewGame,
                onResetScores: _handleResetScores,
                onCellTapped: _handleCellTapped,
              );
            },
          ),
        ],
      ),
    );
  }
}
