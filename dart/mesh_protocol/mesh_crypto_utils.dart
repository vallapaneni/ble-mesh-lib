// This file was moved from the root dart directory to mesh_protocol/ for better modularization.
// mesh_crypto_utils.dart
// Bluetooth Mesh cryptographic utilities (K2, s1, etc.) using PointyCastle
// Copyright (c) 2025

import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// s1 function: AES-CMAC with zero key, as per Bluetooth Mesh spec.
Future<Uint8List> s1(String m) async {
  final key = Uint8List(16); // 16 bytes of zeros
  final cmac = CMac(AESEngine(), 128);
  cmac.init(KeyParameter(key));
  final input = Uint8List.fromList(m.codeUnits);
  final out = Uint8List(cmac.macSize);
  cmac.update(input, 0, input.length);
  cmac.doFinal(out, 0);
  return out;
}

/// Utility: AES-CMAC for mesh (returns 16-byte MAC, prints label if provided)
Uint8List meshAesCmac(Uint8List key, Uint8List input, {String? label}) {
  final cmac = CMac(AESEngine(), 128);
  cmac.init(KeyParameter(key));
  final out = Uint8List(cmac.macSize);
  cmac.update(input, 0, input.length);
  cmac.doFinal(out, 0);
  if (label != null) {
    print('\x1b[36m$label: \x1b[0m${out.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  }
  return out;
}

/// K2 key derivation as per Bluetooth Mesh Profile 3.7.2
Future<Map<String, dynamic>> k2(Uint8List netKey, Uint8List p) async {
  final salt = await s1('smk2');
  final t = meshAesCmac(salt, netKey, label: 'T');

  // T1 = AES-CMAC(T, P || 0x01)
  final t1Input = Uint8List.fromList([...p, 0x01]);
  final t1 = meshAesCmac(t, t1Input, label: 'T1');

  // T2 = AES-CMAC(T, T1 || P || 0x02)
  final t2Input = Uint8List.fromList([...t1, ...p, 0x02]);
  final t2 = meshAesCmac(t, t2Input, label: 'T2');

  // T3 = AES-CMAC(T, T2 || P || 0x03)
  final t3Input = Uint8List.fromList([...t2, ...p, 0x03]);
  final t3 = meshAesCmac(t, t3Input, label: 'T3');

  final nid = t1[15] & 0x7F;
  return {
    'nid': nid,
    'encryptionKey': t2,
    'privacyKey': t3,
  };
}
