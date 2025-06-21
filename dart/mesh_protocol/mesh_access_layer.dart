// mesh_access_layer.dart
// Bluetooth Mesh access layer: convenience API for creating network PDU from model message
import 'dart:typed_data';
import 'mesh_transport_layer.dart';
import 'mesh_network_layer.dart';
import '../mesh_protocol/mesh_crypto_utils.dart';
import '../mesh_data/mesh_network.dart';
import '../mesh_constants.dart';

Future<Uint8List> createNetworkPduFromModelMessage({
  required Uint8List modelMessage,
  required MeshNetwork network,
  required int appIdx,
  required int seq,
  required int src,
  required int dst,
  int ttl = 0x01,
}) async {
  // Use the first NetKey for this example
  final netKey = network.netKeys.first.key;
  final ivIndex = network.ivIndex;
  print('netKey: \x1b[36m${netKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}\x1b[0m');
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
    network: network,
    appIdx: appIdx,
    seq: seq,
    src: src,
    dst: dst,
    ivIndex: ivIndex,
  );
  print('transportPdu: ${transportPdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  // Encrypt at network layer (header + encrypted payload, already obfuscated)
  final networkPdu = await meshNetworkEncrypt(
    transportPdu: transportPdu,
    network: network,
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
