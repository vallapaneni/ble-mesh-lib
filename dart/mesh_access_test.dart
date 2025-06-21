// mesh_access_test.dart
// Unit tests for mesh_access.dart (network PDU creation)
// Copyright (c) 2025

import 'dart:typed_data';
import 'package:test/test.dart';
import 'mesh_access.dart';

void main() {
  group('Mesh Access Layer', () {
    test('createNetworkPduFromModelMessage produces non-empty output', () async {
      // Example test vectors (not real mesh keys/messages)
      final modelMessage = Uint8List.fromList([0x59, 0x00, 0x06, 0x00, 0xe0, 0x01]);
      final appKey = Uint8List.fromList([
        0xf6, 0x35, 0x12, 0xd0, 0xc0, 0xdb, 0x60, 0x9d,
        0xba, 0x79, 0xfa, 0xc8, 0x19, 0x89, 0x37, 0xdf
      ]);
      final netKey = Uint8List.fromList([
        0x77, 0x0e, 0xf5, 0x80, 0xb9, 0x58, 0xc5, 0xc4,
        0xdb, 0xe0, 0x8d, 0x86, 0x34, 0x41, 0x22, 0x57
      ]);
      final seq = 37; //0x000001;
      final src = 32534; //0x1201;
      final dst = 12; //0x2302;
      final ivIndex = 5; // 0x01020304;
      final ttl = 7; //0x01;

      final networkPdu = await createNetworkPduFromModelMessage(
        modelMessage: modelMessage,
        appKey: appKey,
        netKey: netKey,
        seq: seq,
        src: src,
        dst: dst,
        ivIndex: ivIndex,
        ttl: ttl,
      );

      expect(networkPdu, isNotEmpty);
      expect(networkPdu, isA<Uint8List>());
      // Optionally, check length or structure
      expect(networkPdu.length, greaterThan(10));
    });
  });
}
