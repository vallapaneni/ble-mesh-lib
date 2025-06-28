/// A comprehensive Bluetooth Mesh library for Dart.
///
/// This library provides:
/// - Bluetooth Mesh protocol implementation (network, transport, access layers)
/// - Cryptographic utilities for mesh security
/// - Data models for mesh networks, nodes, and configuration
/// - High-level APIs for mesh operations
library ble_mesh_lib;

// Export public API
export 'src/mesh_api.dart';

// Export data models
export 'src/data/mesh_network.dart';
export 'src/data/mesh_node.dart';
export 'src/data/mesh_element.dart';
export 'src/data/mesh_model.dart';
export 'src/data/mesh_netkey.dart';
export 'src/data/mesh_appkey.dart';
export 'src/data/mesh_group.dart';
export 'src/data/mesh_scene.dart';
export 'src/data/mesh_node_features.dart';

// Export constants
export 'src/mesh_constants.dart';

// Export protocol layers (for advanced usage)
export 'src/protocol/mesh_access_layer.dart';
export 'src/protocol/mesh_transport_layer.dart';
export 'src/protocol/mesh_network_layer.dart';
export 'src/protocol/mesh_crypto_utils.dart';
