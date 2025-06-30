// mesh_network.dart
// Top-level MeshNetwork class for Bluetooth Mesh provisioner
import 'dart:typed_data';
import 'dart:convert';
import 'mesh_netkey.dart';
import 'mesh_appkey.dart';
import 'mesh_node.dart';
import 'mesh_group.dart';
import 'mesh_scene.dart';

class MeshNetwork {
  final String uuid;
  final String name;
  final List<MeshNetKey> netKeys;
  final List<MeshAppKey> appKeys;
  final Uint8List provisionerDevKey;
  int nextUnicastAddress;
  final List<MeshNode> nodes;
  final List<MeshGroup> groups;
  final List<MeshScene> scenes;
  int ivIndex;
  int sequenceNumber;
  DateTime timestamp;

  MeshNetwork({
    required this.uuid,
    required this.name,
    required this.netKeys,
    required this.appKeys,
    required this.provisionerDevKey,
    required this.nextUnicastAddress,
    required this.nodes,
    this.groups = const [],
    this.scenes = const [],
    this.ivIndex = 0,
    this.sequenceNumber = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

extension MeshNetworkJson on MeshNetwork {
  static MeshNetwork fromJson(Map<String, dynamic> json) {
    // Assume top-level key is the network UUID
    final networkUuid = json.keys.first;
    final data = json[networkUuid];
    final netKeys = (data['netKeys'] as List).map((nk) => MeshNetKey(
      index: nk['refresh'] ?? 0,
      key: Uint8List.fromList(List<int>.generate(16, (i) => int.parse(nk['key'].substring(i*2, i*2+2), radix: 16))),
      name: '',
    )).toList();
    final appKeys = (data['appKeys'] as List).map((ak) => MeshAppKey(
      index: 0,
      key: Uint8List.fromList(List<int>.generate(16, (i) => int.parse(ak['key'].substring(i*2, i*2+2), radix: 16))),
      boundNetKeyIndex: ak['boundNetKey'] ?? 0,
      name: '',
    )).toList();
    final nodes = (data['nodes'] as List).map((n) => MeshNode(
      uuid: '',
      unicastAddress: n['unicast'],
      devKey: Uint8List.fromList(List<int>.generate(16, (i) => int.parse(n['key'].substring(i*2, i*2+2), radix: 16))),
      elements: const [],
      name: n['name'] ?? '',
      features: MeshNodeFeatures(),
      lastSeen: null,
    )).toList();
    return MeshNetwork(
      uuid: networkUuid,
      name: data['name'] ?? '',
      netKeys: netKeys,
      appKeys: appKeys,
      provisionerDevKey: Uint8List(16), // Not present in JSON, set to zeros
      nextUnicastAddress: data['lowerAddress'] ?? 1,
      nodes: nodes,
      ivIndex: data['ivIndex'] ?? 0,
      sequenceNumber: 0,
    );
  }

  static MeshNetwork fromJsonString(String jsonString) {
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return fromJson(jsonMap);
  }

  /// Converts the MeshNetwork to a JSON-serializable map for Firestore.
  Map<String, dynamic> toJson() {
    return {
      uuid: {
        'name': name,
        'netKeys': netKeys.map((nk) => {
          'refresh': nk.index,
          'key': nk.key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        }).toList(),
        'appKeys': appKeys.map((ak) => {
          'key': ak.key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          'boundNetKey': ak.boundNetKeyIndex,
        }).toList(),
        'nodes': nodes.map((n) => {
          'unicast': n.unicastAddress,
          'key': n.devKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          'name': n.name,
        }).toList(),
        'lowerAddress': nextUnicastAddress,
        'ivIndex': ivIndex,
        'timestamp': timestamp.toIso8601String(),
      }
    };
  }
}
