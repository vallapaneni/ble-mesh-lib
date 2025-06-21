// mesh_transport_layer.dart
// Bluetooth Mesh transport layer encryption (unsegmented, minimal) using PointyCastle
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

Future<Uint8List> meshTransportEncrypt({
  required Uint8List modelMessage,
  required Uint8List appKey,
  required int seq,
  required int src,
  required int dst,
  required int ivIndex,
}) async {
  final nonce = _buildTransportNonce(seq, src, dst, ivIndex);
  final micSize = 4; // 32-bit MIC for unsegmented
  final cipher = CCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(appKey), micSize * 8, nonce, Uint8List(0)),
    );
  final input = modelMessage;
  final output = cipher.process(input);
  return output;
}

Uint8List _buildTransportNonce(int seq, int src, int dst, int ivIndex) {
  final type = 0x01; // 0x01 for application nonce type (FIXME: Take care of decvice nonce based on app Key ID)
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
