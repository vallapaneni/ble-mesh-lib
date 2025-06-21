// mesh_access.dart
// Bluetooth Mesh access layer: convenience API for creating network PDU from model message
// Copyright (c) 2025

import 'dart:typed_data';
import 'mesh_transport.dart';
import 'mesh_network.dart';
import 'mesh_crypto_utils.dart';

Future<Uint8List> createNetworkPduFromModelMessage({
  required Uint8List modelMessage,
  required Uint8List appKey,
  required Uint8List netKey,
  required int seq,
  required int src,
  required int dst,
  required int ivIndex,
  int ttl = 0x01,
}) async {
  print('netKey: ${netKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  // Derive K2 keys and NID from NetKey (P = [0x00] for network)
  final k2Result = await k2(netKey, Uint8List.fromList([0x00]));
  final nid = k2Result['nid'] as int;
  final encryptionKey = k2Result['encryptionKey'] as Uint8List;
  final privacyKey = k2Result['privacyKey'] as Uint8List;
  print('nid: $nid');
  print('encryptionKey: ${encryptionKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  print('privacyKey: ${privacyKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  // Encrypt at transport layer
  final transportPdu = await meshTransportEncrypt(
    modelMessage: modelMessage,
    appKey: appKey,
    seq: seq,
    src: src,
    dst: dst,
    ivIndex: ivIndex,
  );
  print('transportPdu: ${transportPdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  // Encrypt at network layer (header + encrypted payload, already obfuscated)
  final networkPdu = await meshNetworkEncrypt(
    transportPdu: transportPdu,
    encryptionKey: encryptionKey,
    privacyKey: privacyKey,
    seq: seq,
    src: src,
    dst: dst,
    ivIndex: ivIndex,
    ctl: 0,
    ttl: ttl,
    nid: nid,
  );
  print('networkPdu: ${networkPdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  // Return the fully obfuscated network PDU
  return networkPdu;
}
