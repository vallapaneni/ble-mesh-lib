// mesh_model.dart
/// Base class for all Bluetooth Mesh models (server/client, SIG/vendor) for use in mesh_data
abstract class MeshModel {
  int get modelId;
  // Optionally: element reference, publish/subscribe, etc.
}
