// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class GlbBuilder {
  final List<int> _binBuffer = [];
  final List<Map<String, dynamic>> _bufferViews = [];
  final List<Map<String, dynamic>> _accessors = [];
  final List<Map<String, dynamic>> _materials = [];
  final List<Map<String, dynamic>> _meshes = [];
  final List<Map<String, dynamic>> _nodes = [];
  final List<int> _sceneNodes = [];

  int addMaterial({
    required String name,
    required List<double> baseColor,
    double metallic = 0.3,
    double roughness = 0.25,
  }) {
    _materials.add({
      'name': name,
      'pbrMetallicRoughness': {
        'baseColorFactor': baseColor,
        'metallicFactor': metallic,
        'roughnessFactor': roughness,
      },
    });
    return _materials.length - 1;
  }

  int addMesh({
    required String name,
    required Float32List positions,
    required Float32List normals,
    required Uint16List indices,
    required int materialIndex,
  }) {
    // 1. Add Index BufferView & Accessor (Target 34963 = ELEMENT_ARRAY_BUFFER)
    final indexOffset = _align4(_binBuffer.length);
    _padBinBufferTo(indexOffset);
    final indexBytes = indices.buffer.asUint8List(indices.offsetInBytes, indices.lengthInBytes);
    _binBuffer.addAll(indexBytes);

    _bufferViews.add({
      'buffer': 0,
      'byteOffset': indexOffset,
      'byteLength': indexBytes.length,
      'target': 34963, // ELEMENT_ARRAY_BUFFER
    });
    final indexBvIndex = _bufferViews.length - 1;

    _accessors.add({
      'bufferView': indexBvIndex,
      'byteOffset': 0,
      'componentType': 5123, // UNSIGNED_SHORT
      'count': indices.length,
      'type': 'SCALAR',
    });
    final indicesAccIndex = _accessors.length - 1;

    // 2. Add Position BufferView & Accessor (Target 34962 = ARRAY_BUFFER)
    final posOffset = _align4(_binBuffer.length);
    _padBinBufferTo(posOffset);
    final posBytes = positions.buffer.asUint8List(positions.offsetInBytes, positions.lengthInBytes);
    _binBuffer.addAll(posBytes);

    // Compute min/max for positions
    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (int i = 0; i < positions.length; i += 3) {
      minX = math.min(minX, positions[i]);
      maxX = math.max(maxX, positions[i]);
      minY = math.min(minY, positions[i + 1]);
      maxY = math.max(maxY, positions[i + 1]);
      minZ = math.min(minZ, positions[i + 2]);
      maxZ = math.max(maxZ, positions[i + 2]);
    }

    _bufferViews.add({
      'buffer': 0,
      'byteOffset': posOffset,
      'byteLength': posBytes.length,
      'target': 34962, // ARRAY_BUFFER
    });
    final posBvIndex = _bufferViews.length - 1;

    _accessors.add({
      'bufferView': posBvIndex,
      'byteOffset': 0,
      'componentType': 5126, // FLOAT
      'count': positions.length ~/ 3,
      'type': 'VEC3',
      'min': [minX, minY, minZ],
      'max': [maxX, maxY, maxZ],
    });
    final posAccIndex = _accessors.length - 1;

    // 3. Add Normal BufferView & Accessor (Target 34962 = ARRAY_BUFFER)
    final normOffset = _align4(_binBuffer.length);
    _padBinBufferTo(normOffset);
    final normBytes = normals.buffer.asUint8List(normals.offsetInBytes, normals.lengthInBytes);
    _binBuffer.addAll(normBytes);

    _bufferViews.add({
      'buffer': 0,
      'byteOffset': normOffset,
      'byteLength': normBytes.length,
      'target': 34962, // ARRAY_BUFFER
    });
    final normBvIndex = _bufferViews.length - 1;

    _accessors.add({
      'bufferView': normBvIndex,
      'byteOffset': 0,
      'componentType': 5126, // FLOAT
      'count': normals.length ~/ 3,
      'type': 'VEC3',
    });
    final normAccIndex = _accessors.length - 1;

    // 4. Create Mesh Primitive
    _meshes.add({
      'name': name,
      'primitives': [
        {
          'attributes': {
            'POSITION': posAccIndex,
            'NORMAL': normAccIndex,
          },
          'indices': indicesAccIndex,
          'material': materialIndex,
          'mode': 4, // TRIANGLES
        }
      ],
    });
    return _meshes.length - 1;
  }

  int addNode({
    required String name,
    int? meshIndex,
    List<double>? translation,
    List<double>? rotation, // [x, y, z, w] quaternion
    List<double>? scale,
    List<int>? children,
  }) {
    final node = <String, dynamic>{'name': name};
    if (meshIndex != null) node['mesh'] = meshIndex;
    if (translation != null) node['translation'] = translation;
    if (rotation != null) node['rotation'] = rotation;
    if (scale != null) node['scale'] = scale;
    if (children != null && children.isNotEmpty) node['children'] = children;

    _nodes.add(node);
    return _nodes.length - 1;
  }

  void addRootSceneNode(int nodeIndex) {
    _sceneNodes.add(nodeIndex);
  }

  Uint8List buildGlb() {
    // 1. Build JSON Object
    final gltf = {
      'asset': {'version': '2.0', 'generator': 'flutter_scene_generator'},
      'scene': 0,
      'scenes': [
        {'nodes': _sceneNodes}
      ],
      'nodes': _nodes,
      'meshes': _meshes,
      'materials': _materials,
      'accessors': _accessors,
      'bufferViews': _bufferViews,
      'buffers': [
        {'byteLength': _align4(_binBuffer.length)}
      ],
    };

    final jsonString = jsonEncode(gltf);
    final jsonBytes = utf8.encode(jsonString);
    final jsonPaddedLength = _align4(jsonBytes.length);
    final jsonPadding = jsonPaddedLength - jsonBytes.length;

    final binPaddedLength = _align4(_binBuffer.length);
    final binPadding = binPaddedLength - _binBuffer.length;

    // Total GLB size = 12 (header) + 8 (json chunk header) + jsonPaddedLength + 8 (bin chunk header) + binPaddedLength
    final totalGlbSize = 12 + 8 + jsonPaddedLength + 8 + binPaddedLength;

    final bb = BytesBuilder();

    // 1. GLB Header (12 bytes)
    final headerData = ByteData(12);
    headerData.setUint32(0, 0x46546C67, Endian.little); // 'glTF' magic
    headerData.setUint32(4, 2, Endian.little); // version 2
    headerData.setUint32(8, totalGlbSize, Endian.little);
    bb.add(headerData.buffer.asUint8List());

    // 2. JSON Chunk (Chunk 0)
    final jsonChunkHeader = ByteData(8);
    jsonChunkHeader.setUint32(0, jsonPaddedLength, Endian.little);
    jsonChunkHeader.setUint32(4, 0x4E4F534A, Endian.little); // 'JSON'
    bb.add(jsonChunkHeader.buffer.asUint8List());
    bb.add(jsonBytes);
    for (int i = 0; i < jsonPadding; i++) {
      bb.addByte(0x20); // space padding
    }

    // 3. BIN Chunk (Chunk 1)
    final binChunkHeader = ByteData(8);
    binChunkHeader.setUint32(0, binPaddedLength, Endian.little);
    binChunkHeader.setUint32(4, 0x004E4942, Endian.little); // 'BIN\0'
    bb.add(binChunkHeader.buffer.asUint8List());
    bb.add(_binBuffer);
    for (int i = 0; i < binPadding; i++) {
      bb.addByte(0x00); // null padding
    }

    return bb.toBytes();
  }

  int _align4(int val) {
    final rem = val % 4;
    return rem == 0 ? val : val + (4 - rem);
  }

  void _padBinBufferTo(int offset) {
    while (_binBuffer.length < offset) {
      _binBuffer.add(0);
    }
  }
}

// -------------------------------------------------------------
// Geometry Helpers
// -------------------------------------------------------------

class MeshGeometryData {
  final Float32List positions;
  final Float32List normals;
  final Uint16List indices;

  MeshGeometryData({
    required this.positions,
    required this.normals,
    required this.indices,
  });
}

MeshGeometryData createCuboid(double width, double height, double depth) {
  final w = width / 2;
  final h = height / 2;
  final d = depth / 2;

  final positions = Float32List.fromList([
    // Front (+Z)
    -w, -h, d, w, -h, d, w, h, d, -w, h, d,
    // Back (-Z)
    w, -h, -d, -w, -h, -d, -w, h, -d, w, h, -d,
    // Top (+Y)
    -w, h, d, w, h, d, w, h, -d, -w, h, -d,
    // Bottom (-Y)
    -w, -h, -d, w, -h, -d, w, -h, d, -w, -h, d,
    // Right (+X)
    w, -h, d, w, -h, -d, w, h, -d, w, h, d,
    // Left (-X)
    -w, -h, -d, -w, -h, d, -w, h, d, -w, h, -d,
  ]);

  final normals = Float32List.fromList([
    // Front
    0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1,
    // Back
    0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
    // Top
    0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0,
    // Bottom
    0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
    // Right
    1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0,
    // Left
    -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
  ]);

  final indices = Uint16List.fromList([
    0, 1, 2, 0, 2, 3, // Front
    4, 5, 6, 4, 6, 7, // Back
    8, 9, 10, 8, 10, 11, // Top
    12, 13, 14, 12, 14, 15, // Bottom
    16, 17, 18, 16, 18, 19, // Right
    20, 21, 22, 20, 22, 23, // Left
  ]);

  return MeshGeometryData(positions: positions, normals: normals, indices: indices);
}

MeshGeometryData createSphere(double radius, {int segments = 24, int rings = 16}) {
  final positions = <double>[];
  final normals = <double>[];
  final indices = <int>[];

  for (int ring = 0; ring <= rings; ring++) {
    final v = ring / rings;
    final phi = v * math.pi;

    for (int seg = 0; seg <= segments; seg++) {
      final u = seg / segments;
      final theta = u * math.pi * 2;

      final x = -math.sin(phi) * math.sin(theta);
      final y = math.cos(phi);
      final z = -math.sin(phi) * math.cos(theta);

      positions.addAll([x * radius, y * radius, z * radius]);
      normals.addAll([x, y, z]);
    }
  }

  for (int ring = 0; ring < rings; ring++) {
    for (int seg = 0; seg < segments; seg++) {
      final i0 = ring * (segments + 1) + seg;
      final i1 = i0 + 1;
      final i2 = (ring + 1) * (segments + 1) + seg;
      final i3 = i2 + 1;

      indices.addAll([i0, i1, i2, i1, i3, i2]);
    }
  }

  return MeshGeometryData(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    indices: Uint16List.fromList(indices),
  );
}

MeshGeometryData createTorus(double radius, double tubeRadius, {int radialSegments = 32, int tubularSegments = 20}) {
  final positions = <double>[];
  final normals = <double>[];
  final indices = <int>[];

  for (int j = 0; j <= radialSegments; j++) {
    final u = j / radialSegments * math.pi * 2;
    for (int i = 0; i <= tubularSegments; i++) {
      final v = i / tubularSegments * math.pi * 2;

      final x = (radius + tubeRadius * math.cos(v)) * math.cos(u);
      final y = (radius + tubeRadius * math.cos(v)) * math.sin(u);
      final z = tubeRadius * math.sin(v);

      final nx = math.cos(v) * math.cos(u);
      final ny = math.cos(v) * math.sin(u);
      final nz = math.sin(v);

      positions.addAll([x, y, z]);
      normals.addAll([nx, ny, nz]);
    }
  }

  for (int j = 1; j <= radialSegments; j++) {
    for (int i = 1; i <= tubularSegments; i++) {
      final a = (tubularSegments + 1) * j + i - 1;
      final b = (tubularSegments + 1) * (j - 1) + i - 1;
      final c = (tubularSegments + 1) * (j - 1) + i;
      final d = (tubularSegments + 1) * j + i;

      indices.addAll([a, b, d, b, c, d]);
    }
  }

  return MeshGeometryData(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    indices: Uint16List.fromList(indices),
  );
}

void main() {
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  // =============================================================
  // 1. Build X Character GLB
  // =============================================================
  final xGlb = GlbBuilder();

  final xMat = xGlb.addMaterial(
    name: 'X_Material',
    baseColor: [0.96, 0.22, 0.32, 1.0], // Coral / Crimson
    metallic: 0.35,
    roughness: 0.25,
  );
  final eyeWhiteMat = xGlb.addMaterial(
    name: 'EyeWhite_Material',
    baseColor: [0.98, 0.98, 1.0, 1.0],
    metallic: 0.0,
    roughness: 0.1,
  );
  final pupilMat = xGlb.addMaterial(
    name: 'Pupil_Material',
    baseColor: [0.05, 0.05, 0.08, 1.0],
    metallic: 0.0,
    roughness: 0.1,
  );

  final limbGeom = createCuboid(0.18, 0.85, 0.18);
  final limbMesh = xGlb.addMesh(
    name: 'LimbMesh',
    positions: limbGeom.positions,
    normals: limbGeom.normals,
    indices: limbGeom.indices,
    materialIndex: xMat,
  );

  final eyeWhiteGeom = createSphere(0.09, segments: 20, rings: 14);
  final eyeWhiteMesh = xGlb.addMesh(
    name: 'EyeWhiteMesh',
    positions: eyeWhiteGeom.positions,
    normals: eyeWhiteGeom.normals,
    indices: eyeWhiteGeom.indices,
    materialIndex: eyeWhiteMat,
  );

  final pupilGeom = createSphere(0.05, segments: 16, rings: 10);
  final pupilMesh = xGlb.addMesh(
    name: 'PupilMesh',
    positions: pupilGeom.positions,
    normals: pupilGeom.normals,
    indices: pupilGeom.indices,
    materialIndex: pupilMat,
  );

  // Cross Limbs
  final angle = math.pi / 4;
  final sinA = math.sin(angle / 2);
  final cosA = math.cos(angle / 2);

  final limb1Node = xGlb.addNode(
    name: 'Limb1',
    meshIndex: limbMesh,
    rotation: [0, 0, sinA, cosA], // +45 deg Z
  );
  final limb2Node = xGlb.addNode(
    name: 'Limb2',
    meshIndex: limbMesh,
    rotation: [0, 0, -sinA, cosA], // -45 deg Z
  );

  final upperJawNode = xGlb.addNode(
    name: 'UpperJaw',
    children: [limb1Node, limb2Node],
  );

  // Eyes (facing -Z towards camera)
  final pupilLNode = xGlb.addNode(name: 'PupilL', meshIndex: pupilMesh, translation: [0, 0, -0.07]);
  final whiteLNode = xGlb.addNode(name: 'WhiteL', meshIndex: eyeWhiteMesh);
  final eyeLeftNode = xGlb.addNode(
    name: 'EyeLeft',
    translation: [-0.16, 0.22, -0.16],
    children: [whiteLNode, pupilLNode],
  );

  final pupilRNode = xGlb.addNode(name: 'PupilR', meshIndex: pupilMesh, translation: [0, 0, -0.07]);
  final whiteRNode = xGlb.addNode(name: 'WhiteR', meshIndex: eyeWhiteMesh);
  final eyeRightNode = xGlb.addNode(
    name: 'EyeRight',
    translation: [0.16, 0.22, -0.16],
    children: [whiteRNode, pupilRNode],
  );

  final xRootNode = xGlb.addNode(
    name: 'X_Character',
    children: [upperJawNode, eyeLeftNode, eyeRightNode],
  );
  xGlb.addRootSceneNode(xRootNode);

  final xBytes = xGlb.buildGlb();
  File('assets/x_character.glb').writeAsBytesSync(xBytes);
  print('Wrote assets/x_character.glb (${xBytes.length} bytes)');

  // =============================================================
  // 2. Build O Character GLB
  // =============================================================
  final oGlb = GlbBuilder();

  final oMat = oGlb.addMaterial(
    name: 'O_Material',
    baseColor: [0.12, 0.78, 0.96, 1.0], // Azure / Cyan
    metallic: 0.35,
    roughness: 0.2,
  );
  final oEyeWhiteMat = oGlb.addMaterial(
    name: 'EyeWhite_Material',
    baseColor: [0.98, 0.98, 1.0, 1.0],
    metallic: 0.0,
    roughness: 0.1,
  );
  final oPupilMat = oGlb.addMaterial(
    name: 'Pupil_Material',
    baseColor: [0.05, 0.05, 0.08, 1.0],
    metallic: 0.0,
    roughness: 0.1,
  );

  final torusGeom = createTorus(0.35, 0.12, radialSegments: 32, tubularSegments: 20);
  final torusMesh = oGlb.addMesh(
    name: 'TorusMesh',
    positions: torusGeom.positions,
    normals: torusGeom.normals,
    indices: torusGeom.indices,
    materialIndex: oMat,
  );

  final oEyeWhiteGeom = createSphere(0.10, segments: 20, rings: 14);
  final oEyeWhiteMesh = oGlb.addMesh(
    name: 'EyeWhiteMesh',
    positions: oEyeWhiteGeom.positions,
    normals: oEyeWhiteGeom.normals,
    indices: oEyeWhiteGeom.indices,
    materialIndex: oEyeWhiteMat,
  );

  final oPupilGeom = createSphere(0.055, segments: 16, rings: 10);
  final oPupilMesh = oGlb.addMesh(
    name: 'PupilMesh',
    positions: oPupilGeom.positions,
    normals: oPupilGeom.normals,
    indices: oPupilGeom.indices,
    materialIndex: oPupilMat,
  );

  // O Body
  final oBodyNode = oGlb.addNode(
    name: 'O_Body',
    meshIndex: torusMesh,
  );

  // O Eyes (facing -Z towards camera)
  final oPupilLNode = oGlb.addNode(name: 'PupilL', meshIndex: oPupilMesh, translation: [0, 0, -0.07]);
  final oWhiteLNode = oGlb.addNode(name: 'WhiteL', meshIndex: oEyeWhiteMesh);
  final oEyeLeftNode = oGlb.addNode(
    name: 'EyeLeft',
    translation: [-0.18, 0.32, -0.14],
    children: [oWhiteLNode, oPupilLNode],
  );

  final oPupilRNode = oGlb.addNode(name: 'PupilR', meshIndex: oPupilMesh, translation: [0, 0, -0.07]);
  final oWhiteRNode = oGlb.addNode(name: 'WhiteR', meshIndex: oEyeWhiteMesh);
  final oEyeRightNode = oGlb.addNode(
    name: 'EyeRight',
    translation: [0.18, 0.32, -0.14],
    children: [oWhiteRNode, oPupilRNode],
  );

  final oRootNode = oGlb.addNode(
    name: 'O_Character',
    children: [oBodyNode, oEyeLeftNode, oEyeRightNode],
  );
  oGlb.addRootSceneNode(oRootNode);

  final oBytes = oGlb.buildGlb();
  File('assets/o_character.glb').writeAsBytesSync(oBytes);
  print('Wrote assets/o_character.glb (${oBytes.length} bytes)');
}
