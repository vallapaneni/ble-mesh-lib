// mesh_network.dart
// Bluetooth Mesh network layer encryption (minimal, no relay) using PointyCastle
// Copyright (c) 2025

import 'dart:typed_data';
import 'package:pointycastle/export.dart';

Future<Uint8List> meshNetworkEncrypt({
  required Uint8List transportPdu,
  required Uint8List encryptionKey,
  required Uint8List privacyKey,
  required int seq,
  required int src,
  required int dst,
  required int ivIndex,
  required int ctl,
  required int ttl,
  required int nid,
}) async {
  final nonce = _buildNetworkNonce(seq, src, dst, ivIndex, ctl, ttl);
  final micSize = 8; // 64-bit MIC for network
  final cipher = CCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(encryptionKey), micSize * 8, nonce, Uint8List(0)),
    );

  // Network header (unencrypted, authenticated)
  final ivi = (ivIndex >> 24) & 0x01;
  final iviNid = ((ivi << 7) | (nid & 0x7F)) & 0xFF;
  final networkHeader = Uint8List.fromList([
    iviNid,
    (ctl << 7) | (ttl & 0x7F),
    ..._int24ToBytes(seq),
    ..._int16ToBytes(src),
    ..._int16ToBytes(dst),
  ]);

  final output = cipher.process(transportPdu);
  final pdu = Uint8List.fromList([
    ...networkHeader,
    ...output,
  ]);

  // Obfuscate header (bytes 0-6) using privacy key
  final header = pdu.sublist(0, 7);
  final encDstAndPayload = pdu.length > 7 ? pdu.sublist(7, pdu.length >= 14 ? 14 : pdu.length) : Uint8List(0);
  final obfuscatedHeader = obfuscateNetworkHeader(
    header: header,
    privacyKey: privacyKey,
    ivIndex: ivIndex,
    encDstAndPayload: encDstAndPayload,
  );
  // Return obfuscated header + rest of PDU
  return Uint8List.fromList([
    ...obfuscatedHeader,
    ...pdu.sublist(7),
  ]);
}

Uint8List _buildNetworkNonce(int seq, int src, int dst, int ivIndex, int ctl, int ttl) {
  final type = 0x00; // Network nonce type FIXME: take care of proxy nonce type based on ctl and dst
  final ctlTtl = ((ctl & 0x01) << 7) | (ttl & 0x7F);
  return Uint8List.fromList([
    type,
    ctlTtl,
    ..._int24ToBytes(seq),
    ..._int16ToBytes(src),
    0x00, 0x00, // Padding to 13 bytes, FIXME: DST for network nonce
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

/// Obfuscate the network PDU header using the privacy key (Bluetooth Mesh spec 3.8.6)
Uint8List obfuscateNetworkHeader({
  required Uint8List header,
  required Uint8List privacyKey,
  required int ivIndex,
  required Uint8List encDstAndPayload,
}) {
  // Privacy Random = encDstAndPayload[0..6] (first 7 bytes after header)
  // Ensure encDstAndPayload is at least 7 bytes, pad with zeros if needed
  final paddedEncDstAndPayload = Uint8List(7);
  for (int i = 0; i < 7; i++) {
    paddedEncDstAndPayload[i] = (i < encDstAndPayload.length) ? encDstAndPayload[i] : 0;
  }
  final privacyRandom = Uint8List(16);
  // 5 bytes of zeros, then 7 bytes of encDstAndPayload, then 4 bytes of zeros
  for (int i = 0; i < 5; i++) privacyRandom[i] = 0;
  for (int i = 0; i < 7; i++) privacyRandom[5 + i] = paddedEncDstAndPayload[i];
  for (int i = 12; i < 16; i++) privacyRandom[i] = 0;

  // Create PECB = AES-ECB(privacyKey, privacyRandom)
  final cipher = AESEngine()..init(true, KeyParameter(privacyKey));
  final pecb = Uint8List(16);
  cipher.processBlock(privacyRandom, 0, pecb, 0);

  // Obfuscate header fields (bytes 1-6)
  final obfuscated = Uint8List.fromList(header);
  for (int i = 1; i <= 6; i++) {
    obfuscated[i] ^= pecb[i - 1];
  }
  return obfuscated;
}
