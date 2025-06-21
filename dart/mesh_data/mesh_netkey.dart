// mesh_netkey.dart
import 'dart:typed_data';

class MeshNetKey {
  final int index;
  final Uint8List key;
  final String name;
  MeshNetKey({required this.index, required this.key, required this.name});
}
