// mesh_access_test.dart
// Unit tests for mesh_access.dart (network PDU creation)
// Copyright (c) 2025

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:ble_mesh_lib/src/protocol/mesh_access_layer.dart';
import 'dart:io';
import 'package:ble_mesh_lib/src/data/mesh_network.dart';
import 'package:ble_mesh_lib/src/mesh_constants.dart';

void main() {
  group('Mesh Access Layer', () {
    test('createNetworkPduFromModelMessage produces non-empty output (AppKey)', () async {
      // Load real mesh network from ropods7.json
      final jsonString = await File('testdata/ropods7.json').readAsString();
      final network = MeshNetworkJson.fromJsonString(jsonString);
      final modelMessage = Uint8List.fromList([0x59, 0x00, 0x06, 0x00, 0xe0, 0x01]);
      final src = 32534;
      final dst = 0x000C;
      final seq = 37;
      final ttl = 7;
      final appIdx = 0; // Use first app key
      final networkPdu = await createNetworkPduFromModelMessage(
        modelMessage: modelMessage,
        network: network,
        appIdx: appIdx,
        seq: seq,
        src: src,
        dst: dst,
        ttl: ttl,
      );
      expect(networkPdu, isNotEmpty);
      expect(networkPdu, isA<Uint8List>());
      expect(networkPdu.length, greaterThan(10));
    });

    test('createNetworkPduFromModelMessage produces non-empty output (DevKey)', () async {
      final jsonString = await File('testdata/ropods7.json').readAsString();
      final network = MeshNetworkJson.fromJsonString(jsonString);
      final modelMessage = Uint8List.fromList([0x59, 0x00, 0x06, 0x00, 0xe0, 0x01]);
      final src = 32534;
      final dst = 0x000C;
      final seq = 37;
      final ttl = 7;
      final appIdx = APP_IDX_DEV; // Use dev key
      final networkPdu = await createNetworkPduFromModelMessage(
        modelMessage: modelMessage,
        network: network,
        appIdx: appIdx,
        seq: seq,
        src: src,
        dst: dst,
        ttl: ttl,
      );
      expect(networkPdu, isNotEmpty);
      expect(networkPdu, isA<Uint8List>());
      expect(networkPdu.length, greaterThan(10));
    });
  });
}
