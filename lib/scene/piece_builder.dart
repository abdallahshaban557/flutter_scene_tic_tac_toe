import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class PieceBuilder {
  // Shared geometry instances for efficiency
  static late final CuboidGeometry boardBaseGeometry;
  static late final CuboidGeometry tileGeometry;
  static late final CuboidGeometry gridLineHGeometry;
  static late final CuboidGeometry gridLineVGeometry;

  // X piece geometries
  static late final CuboidGeometry xLimbGeometry;
  static late final SphereGeometry eyeWhiteGeometry;
  static late final SphereGeometry pupilGeometry;

  // O piece geometries
  static late final TorusGeometry oBodyGeometry;
  static late final CylinderGeometry oJawHalfGeometry;

  // Particle geometries
  static late final CuboidGeometry crumbGeometry;

  // Shared Materials
  static late final PhysicallyBasedMaterial boardBaseMaterial;
  static late final PhysicallyBasedMaterial tileMaterial;
  static late final PhysicallyBasedMaterial tileWinningMaterial;
  static late final PhysicallyBasedMaterial gridLineMaterial;

  static late final PhysicallyBasedMaterial xMaterial;
  static late final PhysicallyBasedMaterial xWinningMaterial;
  static late final PhysicallyBasedMaterial oMaterial;
  static late final PhysicallyBasedMaterial oWinningMaterial;

  static late final PhysicallyBasedMaterial eyeWhiteMaterial;
  static late final PhysicallyBasedMaterial pupilMaterial;
  static late final PhysicallyBasedMaterial crumbMaterialX;
  static late final PhysicallyBasedMaterial crumbMaterialO;

  static bool _initialized = false;
  static Node? _xGlbTemplate;
  static Node? _oGlbTemplate;

  static Future<void> loadCharacterGlbs() async {
    initialize();
    try {
      _xGlbTemplate = await Node.fromGlbAsset('assets/x_character.glb');
    } catch (e) {
      // Fallback to procedural if asset fails to load
    }
    try {
      _oGlbTemplate = await Node.fromGlbAsset('assets/o_character.glb');
    } catch (e) {
      // Fallback to procedural if asset fails to load
    }
  }

  static void initialize() {
    if (_initialized) return;

    // Board Geometries
    boardBaseGeometry = CuboidGeometry(vm.Vector3(3.8, 0.25, 3.8));
    tileGeometry = CuboidGeometry(vm.Vector3(0.98, 0.08, 0.98));
    gridLineHGeometry = CuboidGeometry(vm.Vector3(3.4, 0.12, 0.06));
    gridLineVGeometry = CuboidGeometry(vm.Vector3(0.06, 0.12, 3.4));

    // Character Geometries
    xLimbGeometry = CuboidGeometry(vm.Vector3(0.18, 0.85, 0.18));
    eyeWhiteGeometry = SphereGeometry(radius: 0.09, segments: 24, rings: 16);
    pupilGeometry = SphereGeometry(radius: 0.05, segments: 16, rings: 12);

    oBodyGeometry = TorusGeometry(radius: 0.35, tubeRadius: 0.12, radialSegments: 32, tubularSegments: 20);
    oJawHalfGeometry = CylinderGeometry(bottomRadius: 0.35, topRadius: 0.35, height: 0.14, radialSegments: 32);

    crumbGeometry = CuboidGeometry(vm.Vector3(0.06, 0.06, 0.06));

    // Board Materials
    boardBaseMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.1, 0.12, 0.16, 1.0)
      ..roughnessFactor = 0.35
      ..metallicFactor = 0.2;

    tileMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.18, 0.21, 0.28, 1.0)
      ..roughnessFactor = 0.6
      ..metallicFactor = 0.1;

    tileWinningMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.3, 0.8, 0.4, 1.0)
      ..roughnessFactor = 0.3
      ..metallicFactor = 0.3
      ..emissiveFactor = vm.Vector4(0.2, 0.7, 0.3, 1.0)
      ..emissiveStrength = 0.8;

    gridLineMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.85, 0.7, 0.25, 1.0)
      ..metallicFactor = 0.85
      ..roughnessFactor = 0.2
      ..emissiveFactor = vm.Vector4(0.4, 0.3, 0.1, 1.0)
      ..emissiveStrength = 0.6;

    // X Character Materials (Warm Coral / Crimson)
    xMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.96, 0.22, 0.32, 1.0)
      ..metallicFactor = 0.3
      ..roughnessFactor = 0.25
      ..clearcoat = 0.6
      ..emissiveFactor = vm.Vector4(0.2, 0.04, 0.06, 1.0)
      ..emissiveStrength = 0.4;

    xWinningMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(1.0, 0.35, 0.45, 1.0)
      ..metallicFactor = 0.4
      ..roughnessFactor = 0.15
      ..clearcoat = 0.9
      ..emissiveFactor = vm.Vector4(0.8, 0.15, 0.25, 1.0)
      ..emissiveStrength = 1.2;

    // O Character Materials (Vibrant Cyan / Azure)
    oMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.78, 0.96, 1.0)
      ..metallicFactor = 0.3
      ..roughnessFactor = 0.2
      ..clearcoat = 0.7
      ..emissiveFactor = vm.Vector4(0.04, 0.15, 0.25, 1.0)
      ..emissiveStrength = 0.4;

    oWinningMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.25, 0.9, 1.0, 1.0)
      ..metallicFactor = 0.4
      ..roughnessFactor = 0.15
      ..clearcoat = 0.9
      ..emissiveFactor = vm.Vector4(0.15, 0.6, 0.9, 1.0)
      ..emissiveStrength = 1.2;

    // Eyes
    eyeWhiteMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.98, 0.98, 1.0, 1.0)
      ..roughnessFactor = 0.1
      ..metallicFactor = 0.0;

    pupilMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.05, 0.05, 0.08, 1.0)
      ..roughnessFactor = 0.1
      ..metallicFactor = 0.0;

    // Crumbs
    crumbMaterialX = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.96, 0.22, 0.32, 1.0)
      ..roughnessFactor = 0.3;

    crumbMaterialO = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.78, 0.96, 1.0)
      ..roughnessFactor = 0.3;

    _initialized = true;
  }

  /// Builds the 3D Board platform containing the base, grid lines, and 9 tile nodes
  static Node buildBoard(List<Node> tileNodesOut) {
    initialize();
    final boardRoot = Node(name: "BoardRoot");

    // 1. Base Slab
    final baseNode = Node(
      name: "BoardBase",
      mesh: Mesh(boardBaseGeometry, boardBaseMaterial),
    )..position = vm.Vector3(0, -0.125, 0);
    boardRoot.add(baseNode);

    // 2. Grid lines
    final lineH1 = Node(mesh: Mesh(gridLineHGeometry, gridLineMaterial))
      ..position = vm.Vector3(0, 0.02, -0.55);
    final lineH2 = Node(mesh: Mesh(gridLineHGeometry, gridLineMaterial))
      ..position = vm.Vector3(0, 0.02, 0.55);
    final lineV1 = Node(mesh: Mesh(gridLineVGeometry, gridLineMaterial))
      ..position = vm.Vector3(-0.55, 0.02, 0);
    final lineV2 = Node(mesh: Mesh(gridLineVGeometry, gridLineMaterial))
      ..position = vm.Vector3(0.55, 0.02, 0);

    boardRoot.addAll([lineH1, lineH2, lineV1, lineV2]);

    // 3. 9 Tile Cells
    tileNodesOut.clear();
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final index = r * 3 + c;
        final x = (c - 1) * 1.1;
        final z = (r - 1) * 1.1;

        final tile = Node(
          name: "Tile_$index",
          mesh: Mesh(tileGeometry, tileMaterial),
        )..position = vm.Vector3(x, 0.0, z);

        boardRoot.add(tile);
        tileNodesOut.add(tile);
      }
    }

    return boardRoot;
  }

  /// Converts grid cell index (0..8) to world position on the board
  static vm.Vector3 cellToWorldPosition(int index, {double yOffset = 0.45}) {
    final r = index ~/ 3;
    final c = index % 3;
    final x = (c - 1) * 1.1;
    final z = (r - 1) * 1.1;
    return vm.Vector3(x, yOffset, z);
  }

  /// Creates a stylized 3D X Character Node with animated mouth & eyes
  static Node createXCharacter({bool isWinning = false}) {
    if (_xGlbTemplate != null) {
      final clone = _xGlbTemplate!.clone(recursive: true);
      clone.name = "X_Root";
      return clone;
    }

    initialize();
    final xRoot = Node(name: "X_Root");

    // Upper Jaw / Top Cross Arm Node (can tilt up during chomp)
    final upperJawNode = Node(name: "UpperJaw");
    final limb1 = Node(
      mesh: Mesh(xLimbGeometry, isWinning ? xWinningMaterial : xMaterial),
    )..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 4);

    final limb2 = Node(
      mesh: Mesh(xLimbGeometry, isWinning ? xWinningMaterial : xMaterial),
    )..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -math.pi / 4);

    upperJawNode.addAll([limb1, limb2]);
    xRoot.add(upperJawNode);

    // Eyes attached to the front of X (-Z facing camera)
    final eyeLeftNode = _createEyeNode(isLeft: true);
    final eyeRightNode = _createEyeNode(isLeft: false);
    eyeLeftNode.position = vm.Vector3(-0.16, 0.22, -0.16);
    eyeRightNode.position = vm.Vector3(0.16, 0.22, -0.16);

    xRoot.addAll([eyeLeftNode, eyeRightNode]);

    return xRoot;
  }

  /// Creates a stylized 3D O Character Node with animated mouth & eyes
  static Node createOCharacter({bool isWinning = false}) {
    if (_oGlbTemplate != null) {
      final clone = _oGlbTemplate!.clone(recursive: true);
      clone.name = "O_Root";
      return clone;
    }

    initialize();
    final oRoot = Node(name: "O_Root");

    // Main Torus Body (oriented in XY plane facing forward)
    final bodyNode = Node(name: "O_Body");
    final torusMeshNode = Node(
      mesh: Mesh(oBodyGeometry, isWinning ? oWinningMaterial : oMaterial),
    )..rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2);

    bodyNode.add(torusMeshNode);
    oRoot.add(bodyNode);

    // Big expressive cartoon eyes at the top (-Z facing camera)
    final eyeLeftNode = _createEyeNode(isLeft: true, eyeScale: 1.1);
    final eyeRightNode = _createEyeNode(isLeft: false, eyeScale: 1.1);
    eyeLeftNode.position = vm.Vector3(-0.18, 0.32, -0.14);
    eyeRightNode.position = vm.Vector3(0.18, 0.32, -0.14);

    oRoot.addAll([eyeLeftNode, eyeRightNode]);

    return oRoot;
  }

  static Node _createEyeNode({required bool isLeft, double eyeScale = 1.0}) {
    final eyeRoot = Node(name: isLeft ? "EyeLeft" : "EyeRight");

    // White eyeball
    final whiteNode = Node(
      mesh: Mesh(eyeWhiteGeometry, eyeWhiteMaterial),
    )..scale = vm.Vector3.all(eyeScale);

    // Pupil facing forward towards viewer (-Z)
    final pupilNode = Node(
      mesh: Mesh(pupilGeometry, pupilMaterial),
    )..position = vm.Vector3(0, 0, -0.07 * eyeScale);

    eyeRoot.addAll([whiteNode, pupilNode]);
    return eyeRoot;
  }

  /// Creates a burst of crumb particles for a chomp event
  static List<Node> createChompParticles(vm.Vector3 position, bool isXPiece) {
    initialize();
    final rng = math.Random();
    final mat = isXPiece ? crumbMaterialX : crumbMaterialO;
    final particles = <Node>[];

    for (int i = 0; i < 14; i++) {
      final p = Node(
        name: "Crumb_$i",
        mesh: Mesh(crumbGeometry, mat),
      )
        ..position = vm.Vector3(
          position.x + (rng.nextDouble() - 0.5) * 0.3,
          position.y + (rng.nextDouble() - 0.5) * 0.3,
          position.z + (rng.nextDouble() - 0.5) * 0.3,
        )
        ..scale = vm.Vector3.all(0.6 + rng.nextDouble() * 0.8);

      particles.add(p);
    }
    return particles;
  }
}
