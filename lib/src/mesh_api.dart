/// High-level API for Bluetooth Mesh operations.
///
/// This class provides a simplified interface for common mesh operations
/// such as sending messages, managing nodes, and handling network configuration.

import 'dart:typed_data';
import 'data/mesh_network.dart';
import 'protocol/mesh_access_layer.dart';

/// Main API class for Bluetooth Mesh operations.
class BleMeshApi {
  final MeshNetwork _network;

  /// Creates a new BleMeshApi instance with the given network.
  BleMeshApi(this._network);

  /// Gets the current mesh network.
  MeshNetwork get network => _network;

  /// Sends a model message to a destination address.
  ///
  /// [modelMessage] - The message payload to send
  /// [src] - Source address
  /// [dst] - Destination address
  /// [appIdx] - Application key index (use APP_IDX_DEV for device key)
  /// [seq] - Sequence number
  /// [ttl] - Time to live (default: 7)
  ///
  /// Returns the network PDU ready for transmission.
  Future<Uint8List> sendModelMessage({
    required Uint8List modelMessage,
    required int src,
    required int dst,
    required int appIdx,
    required int seq,
    int ttl = 7,
  }) async {
    return await createNetworkPduFromModelMessage(
      modelMessage: modelMessage,
      network: _network,
      appIdx: appIdx,
      seq: seq,
      src: src,
      dst: dst,
      ttl: ttl,
    );
  }

  /// Gets the next sequence number for the network.
  int getNextSequenceNumber() {
    return ++_network.sequenceNumber;
  }

  /// Updates the IV index for the network.
  void updateIvIndex(int newIvIndex) {
    _network.ivIndex = newIvIndex;
  }
}
