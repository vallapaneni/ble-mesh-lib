// mesh_element.dart
import 'mesh_model.dart';

class MeshElement {
  final int location;
  final List<MeshModel> models;
  MeshElement({required this.location, required this.models});
}
