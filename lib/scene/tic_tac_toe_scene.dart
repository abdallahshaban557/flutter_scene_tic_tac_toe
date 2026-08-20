import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../game/game_controller.dart';
import 'piece_builder.dart';
import 'animated_piece.dart';

class TicTacToe3DScene {
  final GameController gameController;
  final Scene scene = Scene();

  late final Node cameraNode;
  OrbitCameraController? orbitController;

  final List<Node> _tileNodes = [];
  final Map<int, AnimatedPiece> _activePieces = {};
  final List<AnimatedCrumbParticle> _activeParticles = [];
  final Node _piecesRoot = Node(name: "PiecesRoot");
  final Node _particlesRoot = Node(name: "ParticlesRoot");

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  TicTacToe3DScene({required this.gameController});

  Future<void> load() async {
    // 1. Initialize static resources
    await Scene.initializeStaticResources();
    PieceBuilder.initialize();

    // 2. Configure Stylized / Showcase Look & Post-Processing
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      exposure: 1.05,
      bloomEnabled: true,
      bloomThreshold: 0.95,
      bloomIntensity: 0.22,
      bloomScatter: 0.7,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionIntensity: 0.9,
      vignetteEnabled: true,
      vignetteIntensity: 0.25,
      colorGradingEnabled: true,
      saturation: 1.15,
      contrast: 1.08,
    );

    // 3. Directional Light with Soft Shadows
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.4, -1.0, -0.35).normalized(),
      intensity: 3.8,
      castsShadow: true,
      shadowSoftness: 0.08,
      shadowMapResolution: 1024,
    );

    // 4. Camera Node setup
    orbitController = OrbitCameraController(
      target: vm.Vector3(0, 0.2, 0),
      distance: 7.2,
      polar: 0.75, // ~43 degrees downward view
      azimuth: 0.0,
      smoothing: 0.15,
    );

    cameraNode = Node(name: "MainCamera")
      ..addComponent(CameraComponent(activateOnMount: true))
      ..addComponent(orbitController!)
      ..lookAtFrom(vm.Vector3(0, 5.2, -5.2), vm.Vector3(0, 0.2, 0));

    scene.add(cameraNode);

    // 5. Build 3D Board
    final boardRoot = PieceBuilder.buildBoard(_tileNodes);
    scene.add(boardRoot);
    scene.add(_piecesRoot);
    scene.add(_particlesRoot);

    // 6. Connect GameController Callbacks
    _bindControllerEvents();

    _isLoaded = true;
  }

  void _bindControllerEvents() {
    gameController.onPiecePlaced = (index, pieceType) {
      _spawnPiece(index, pieceType);
    };

    gameController.onWinTriggered = (winResult, loserIndices) {
      _onWin(winResult, loserIndices);
    };

    gameController.onChompStep = (winnerIndex, loserIndex, onChompDone) {
      _executeChomp(winnerIndex, loserIndex, onChompDone);
    };

    gameController.onFeastCompleted = () {
      _onFeastDone();
    };
  }

  void _spawnPiece(int index, CellState pieceType) {
    // Remove existing piece at this cell if any
    if (_activePieces.containsKey(index)) {
      final oldPiece = _activePieces.remove(index)!;
      _piecesRoot.remove(oldPiece.rootNode);
    }

    final pieceNode = (pieceType == CellState.x)
        ? PieceBuilder.createXCharacter()
        : PieceBuilder.createOCharacter();

    _piecesRoot.add(pieceNode);

    final animated = AnimatedPiece(
      cellIndex: index,
      pieceType: pieceType,
      rootNode: pieceNode,
    );

    animated.onActionDone = () {
      gameController.onPieceSpawnFinished();
    };

    _activePieces[index] = animated;
  }

  void _onWin(WinResult winResult, List<int> loserIndices) {
    // 1. Highlight winning tiles
    for (final idx in winResult.winningIndices) {
      if (idx < _tileNodes.length) {
        _tileNodes[idx].mesh = Mesh(PieceBuilder.tileGeometry, PieceBuilder.tileWinningMaterial);
      }
    }

    // 2. Set winning pieces to celebrate
    for (final idx in winResult.winningIndices) {
      if (_activePieces.containsKey(idx)) {
        _activePieces[idx]!.state = PieceAnimState.celebrating;
        _activePieces[idx]!.stateTime = 0.0;
      }
    }
  }

  void _executeChomp(int winnerIndex, int loserIndex, VoidCallback onChompDone) {
    final winnerPiece = _activePieces[winnerIndex];
    final loserPiece = _activePieces[loserIndex];

    if (winnerPiece == null || loserPiece == null) {
      onChompDone();
      return;
    }

    final targetPos = PieceBuilder.cellToWorldPosition(loserIndex);

    // Winner moves toward loser
    winnerPiece.startEatingTrip(targetPos, () {
      // Arrived at loser position!
      // Loser piece starts trembling and shrinking into winner's mouth
      loserPiece.startBeingEaten(winnerPiece.rootNode.position);

      // Spawn burst crumb particles
      final particles = PieceBuilder.createChompParticles(
        targetPos,
        loserPiece.pieceType == CellState.x,
      );
      final rng = math.Random();
      for (final p in particles) {
        _particlesRoot.add(p);
        final vel = vm.Vector3(
          (rng.nextDouble() - 0.5) * 4.0,
          2.5 + rng.nextDouble() * 3.5,
          (rng.nextDouble() - 0.5) * 4.0,
        );
        _activeParticles.add(AnimatedCrumbParticle(
          node: p,
          velocity: vel,
          maxLifetime: 0.8 + rng.nextDouble() * 0.4,
        ));
      }

      // Winner snaps mouth shut in a chomp
      winnerPiece.startChomp(onChompFinished: () {
        // Remove loser piece from 3D hierarchy
        _piecesRoot.remove(loserPiece.rootNode);
        _activePieces.remove(loserIndex);

        onChompDone();
      });
    });
  }

  void _onFeastDone() {
    // Winner returns back to base position
    final winnerIndex = gameController.winResult?.winningIndices[1] ?? 4;
    final winnerPiece = _activePieces[winnerIndex];
    if (winnerPiece != null) {
      winnerPiece.startReturnHome(() {
        winnerPiece.state = PieceAnimState.celebrating;
      });
    }
  }

  void resetBoard() {
    // Clear all piece nodes
    for (final piece in _activePieces.values) {
      _piecesRoot.remove(piece.rootNode);
    }
    _activePieces.clear();

    // Clear particles
    for (final p in _activeParticles) {
      _particlesRoot.remove(p.node);
    }
    _activeParticles.clear();

    // Reset tile materials
    for (final tile in _tileNodes) {
      tile.mesh = Mesh(PieceBuilder.tileGeometry, PieceBuilder.tileMaterial);
    }
  }

  void resetCamera() {
    if (orbitController != null) {
      cameraNode.removeComponent(orbitController!);
      orbitController = OrbitCameraController(
        target: vm.Vector3(0, 0.2, 0),
        distance: 7.2,
        polar: 0.75,
        azimuth: 0.0,
        smoothing: 0.15,
      );
      cameraNode.addComponent(orbitController!);
    }
  }

  void tick(double dt) {
    if (!_isLoaded) return;

    // Cap delta time to prevent physics anomalies on tab pause
    final clampedDt = math.min(0.05, dt);

    // Update active pieces
    for (final piece in _activePieces.values) {
      piece.update(clampedDt);
    }

    // Update particle crumbs
    _activeParticles.removeWhere((p) {
      final alive = p.update(clampedDt);
      if (!alive) {
        _particlesRoot.remove(p.node);
      }
      return !alive;
    });
  }

  /// Exact 3D ray-plane intersection picking for the board
  int? pickCellAtScreenPoint(Offset localPosition, Size viewSize) {
    if (!_isLoaded) return null;
    final cameraComponent = cameraNode.getComponent<CameraComponent>();
    final camera = cameraComponent?.toCamera() ?? scene.camera;
    if (camera == null) return null;

    final ray = camera.screenPointToRay(localPosition, viewSize);

    // Plane y = 0.0 intersection: ray.origin.y + t * ray.direction.y = 0.0
    if (ray.direction.y.abs() < 1e-5) return null;
    final t = -ray.origin.y / ray.direction.y;
    if (t < 0) return null; // Behind camera

    final hitX = ray.origin.x + ray.direction.x * t;
    final hitZ = ray.origin.z + ray.direction.z * t;

    int? bestCell;
    double bestDistSq = double.infinity;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final cellX = (c - 1) * 1.1;
        final cellZ = (r - 1) * 1.1;
        final dx = hitX - cellX;
        final dz = hitZ - cellZ;

        // Tile size is approx 1.0 x 1.0 with 1.1 spacing, so +/- 0.55 covers the entire tile area
        if (dx.abs() <= 0.60 && dz.abs() <= 0.60) {
          final distSq = dx * dx + dz * dz;
          if (distSq < bestDistSq) {
            bestDistSq = distSq;
            bestCell = r * 3 + c;
          }
        }
      }
    }

    return bestCell;
  }
}
