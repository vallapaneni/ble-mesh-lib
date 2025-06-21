// mesh_appkey.dart
import 'dart:typed_data';

class MeshAppKey {
  final int index;
  final Uint8List key;
  final int boundNetKeyIndex;
  final String name;
  MeshAppKey({required this.index, required this.key, required this.boundNetKeyIndex, required this.name});
}
