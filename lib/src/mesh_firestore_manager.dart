/// Firestore integration for Bluetooth Mesh networks.
///
/// This class manages the storage and retrieval of mesh networks from Firestore.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data/mesh_network.dart';

/// Manages Firestore operations for mesh networks.
class MeshFirestoreManager {
  final FirebaseFirestore _firestore;
  final String _networksCollection;

  /// Creates a new MeshFirestoreManager with the given Firestore instance.
  ///
  /// [firestore] - The Firestore instance to use
  /// [networksCollection] - The collection name for storing networks (default: 'mesh_networks')
  MeshFirestoreManager(
    this._firestore, {
    String networksCollection = 'mesh_networks',
  }) : _networksCollection = networksCollection;

  /// Retrieves all mesh networks from Firestore.
  ///
  /// Returns a list of [MeshNetwork] objects.
  Future<List<MeshNetwork>> getAllNetworks() async {
    try {
      final querySnapshot = await _firestore.collection(_networksCollection).get();
      final networks = <MeshNetwork>[];

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final network = MeshNetworkJson.fromJson(data);
          networks.add(network);
        } catch (e) {
          print('Error parsing network ${doc.id}: $e');
          // Continue with other networks if one fails to parse
        }
      }

      return networks;
    } catch (e) {
      print('Error retrieving networks from Firestore: $e');
      rethrow;
    }
  }

  /// Retrieves a specific mesh network by ID from Firestore.
  ///
  /// [networkId] - The ID of the network to retrieve
  /// Returns the [MeshNetwork] if found, null otherwise.
  Future<MeshNetwork?> getNetwork(String networkId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_networksCollection)
          .doc(networkId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) {
        return null;
      }

      return MeshNetworkJson.fromJson(data);
    } catch (e) {
      print('Error retrieving network $networkId from Firestore: $e');
      rethrow;
    }
  }

  /// Saves a mesh network to Firestore.
  ///
  /// [network] - The network to save
  /// [networkId] - Optional ID for the document. If not provided, uses network.uuid
  Future<void> saveNetwork(MeshNetwork network, {String? networkId}) async {
    try {
      final docId = networkId ?? network.uuid;
      final networkJson = network.toJson();

      await _firestore
          .collection(_networksCollection)
          .doc(docId)
          .set(networkJson);
    } catch (e) {
      print('Error saving network to Firestore: $e');
      rethrow;
    }
  }

  /// Updates a mesh network in Firestore.
  ///
  /// [network] - The network to update
  /// [networkId] - Optional ID for the document. If not provided, uses network.uuid
  Future<void> updateNetwork(MeshNetwork network, {String? networkId}) async {
    try {
      final docId = networkId ?? network.uuid;
      final networkJson = network.toJson();

      await _firestore
          .collection(_networksCollection)
          .doc(docId)
          .update(networkJson);
    } catch (e) {
      print('Error updating network in Firestore: $e');
      rethrow;
    }
  }

  /// Deletes a mesh network from Firestore.
  ///
  /// [networkId] - The ID of the network to delete
  Future<void> deleteNetwork(String networkId) async {
    try {
      await _firestore
          .collection(_networksCollection)
          .doc(networkId)
          .delete();
    } catch (e) {
      print('Error deleting network from Firestore: $e');
      rethrow;
    }
  }

  /// Listens to changes in mesh networks collection.
  ///
  /// Returns a stream of [List<MeshNetwork>] that updates when networks change.
  Stream<List<MeshNetwork>> watchNetworks() {
    return _firestore
        .collection(_networksCollection)
        .snapshots()
        .map((querySnapshot) {
      final networks = <MeshNetwork>[];

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final network = MeshNetworkJson.fromJson(data);
          networks.add(network);
        } catch (e) {
          print('Error parsing network ${doc.id} in stream: $e');
          // Continue with other networks if one fails to parse
        }
      }

      return networks;
    });
  }

  /// Listens to changes in a specific mesh network.
  ///
  /// [networkId] - The ID of the network to watch
  /// Returns a stream of [MeshNetwork?] that updates when the network changes.
  Stream<MeshNetwork?> watchNetwork(String networkId) {
    return _firestore
        .collection(_networksCollection)
        .doc(networkId)
        .snapshots()
        .map((docSnapshot) {
      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) {
        return null;
      }

      try {
        return MeshNetworkJson.fromJson(data);
      } catch (e) {
        print('Error parsing network $networkId in stream: $e');
        return null;
      }
    });
  }
}
