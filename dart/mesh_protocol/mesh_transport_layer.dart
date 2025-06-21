// mesh_transport_layer.dart
// Bluetooth Mesh transport layer encryption (unsegmented, minimal) using PointyCastle
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../mesh_data/mesh_network.dart';
import '../mesh_constants.dart';

Future<Uint8List> meshTransportEncrypt({
  required Uint8List modelMessage,
  required MeshNetwork network,
  required int appIdx,
  required int seq,
  required int src,
  required int dst,
  required int ivIndex,
}) async {
  // Select key: devKey if appIdx==APP_IDX_DEV, else appKey at appIdx
  final Uint8List key = (appIdx == APP_IDX_DEV)
      ? network.provisionerDevKey
      : network.appKeys[appIdx].key;
  final nonce = _buildTransportNonce(seq, src, dst, ivIndex, appIdx);
  final micSize = 4; // 32-bit MIC for unsegmented
  final cipher = CCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(key), micSize * 8, nonce, Uint8List(0)),
    );
  final input = modelMessage;
  final output = cipher.process(input);
  return output;
}

Uint8List _buildTransportNonce(int seq, int src, int dst, int ivIndex, int appIdx) {
  // 0x01 for application nonce, 0x02 for device nonce
  final type = (appIdx == APP_IDX_DEV) ? 0x02 : 0x01;
  final aszmic = 0x00; // 0 for unsegmented
  return Uint8List.fromList([
    type,
    aszmic,
    ..._int24ToBytes(seq),
    ..._int16ToBytes(src),
    ..._int16ToBytes(dst),
    ..._int32ToBytes(ivIndex),
  ]);
}

Uint8List _int24ToBytes(int value) => Uint8List.fromList([
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

Uint8List _int16ToBytes(int value) => Uint8List.fromList([
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

Uint8List _int32ToBytes(int value) => Uint8List.fromList([
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);
