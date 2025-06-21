// mesh_node.dart
import 'dart:typed_data';
import 'mesh_element.dart';

class MeshNode {
  final String uuid;
  final int unicastAddress;
  final Uint8List devKey;
  final List<MeshElement> elements;
  final String name;
  final MeshNodeFeatures features;
  final DateTime? lastSeen;
  MeshNode({
    required this.uuid,
    required this.unicastAddress,
    required this.devKey,
    required this.elements,
    required this.name,
    required this.features,
    this.lastSeen,
  });
}

class MeshNodeFeatures {
  MeshNodeFeatures();
}
