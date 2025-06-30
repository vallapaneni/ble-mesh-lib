/// Simple initializer for the Bluetooth Mesh library with Firestore integration.
///
/// This class provides a centralized way to initialize the mesh library
/// with Firestore support and local caching for better performance.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'mesh_firestore_manager.dart';
import 'mesh_data_manager.dart';
import 'mesh_scanner.dart';

/// Simple initializer class for the Bluetooth Mesh library.
class BleMeshLibInitializer {
  static BleMeshLibInitializer? _instance;
  late final MeshDataManager _dataManager;
  late final MeshScanner _scanner;

  BleMeshLibInitializer._internal(
    FirebaseFirestore firestore, {
    String? networksCollection,
    String? devicesCollection,
  }) {
    final firestoreManager = MeshFirestoreManager(
      firestore,
      networksCollection: networksCollection ?? 'mesh_networks',
    );
    _dataManager = MeshDataManager(
      firestoreManager,
      firestore,
      devicesCollection: devicesCollection ?? 'devices',
    );
    _scanner = MeshScanner(_dataManager);
  }

  /// Initializes the Bluetooth Mesh library with Firestore integration.
  ///
  /// [firestore] - The Firestore instance to use for network persistence
  /// [networksCollection] - Optional collection name for storing networks (default: 'mesh_networks')
  /// [devicesCollection] - Optional collection name for device information (default: 'devices')
  ///
  /// This method should be called once during app initialization.
  /// Networks will only be watched when explicitly requested via getNetwork() or watchNetwork().
  static BleMeshLibInitializer initialize(
    FirebaseFirestore firestore, {
    String? networksCollection,
    String? devicesCollection,
  }) {
    _instance = BleMeshLibInitializer._internal(
      firestore,
      networksCollection: networksCollection,
      devicesCollection: devicesCollection,
    );
    
    return _instance!;
  }

  /// Gets the singleton instance of the initializer.
  ///
  /// Throws [StateError] if [initialize] hasn't been called yet.
  static BleMeshLibInitializer get instance {
    if (_instance == null) {
      throw StateError(
        'BleMeshLibInitializer has not been initialized. '
        'Call BleMeshLibInitializer.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Gets the data manager instance for all network operations.
  MeshDataManager get dataManager => _dataManager;

  /// Gets the mesh scanner instance for device discovery and network detection.
  MeshScanner get scanner => _scanner;
}
