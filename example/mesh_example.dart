/// Example demonstrating how to use the BLE Mesh Library
/// 
/// This example shows:
/// - Loading a mesh network from JSON
/// - Creating a mesh API instance
/// - Sending model messages
/// - Using different encryption keys

import 'dart:typed_data';
import 'dart:io';
import 'package:ble_mesh_lib/ble_mesh_lib.dart';

void main() async {
  await basicUsageExample();
  await advancedUsageExample();
}

/// Basic usage example using the high-level API
Future<void> basicUsageExample() async {
  print('=== Basic Usage Example ===');
  
  try {
    // Load mesh network from JSON file
    final jsonString = await File('testdata/ropods7.json').readAsString();
    final network = MeshNetworkJson.fromJsonString(jsonString);
    
    // Create mesh API instance
    final meshApi = BleMeshApi(network);
    
    print('Loaded network: ${network.name}');
    print('Number of nodes: ${network.nodes.length}');
    print('Number of app keys: ${network.appKeys.length}');
    
    // Prepare a model message
    final modelMessage = Uint8List.fromList([0x59, 0x00, 0x06, 0x00, 0xe0, 0x01]);
    
    // Send message using first app key
    final networkPdu = await meshApi.sendModelMessage(
      modelMessage: modelMessage,
      src: 0x7F06, // Source address
      dst: 0x000C, // Destination address
      appIdx: 0,   // Use first app key
      seq: meshApi.getNextSequenceNumber(),
      ttl: 7,
    );
    
    print('Network PDU created successfully!');
    print('PDU length: ${networkPdu.length} bytes');
    print('PDU (hex): ${networkPdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    
  } catch (e) {
    print('Error in basic example: $e');
  }
}

/// Advanced usage example using protocol layers directly
Future<void> advancedUsageExample() async {
  print('\n=== Advanced Usage Example ===');
  
  try {
    // Load mesh network
    final jsonString = await File('testdata/ropods7.json').readAsString();
    final network = MeshNetworkJson.fromJsonString(jsonString);
    
    // Create model message
    final modelMessage = Uint8List.fromList([0x80, 0x03, 0x00, 0x01]); // Different message
    
    // Send using device key (for configuration messages)
    final networkPduWithDevKey = await createNetworkPduFromModelMessage(
      modelMessage: modelMessage,
      network: network,
      appIdx: APP_IDX_DEV, // Use device key
      seq: 42,
      src: 0x0001, // Provisioner address
      dst: 0x0003, // Target node
      ttl: 5,
    );
    
    print('Network PDU with DevKey created!');
    print('PDU length: ${networkPduWithDevKey.length} bytes');
    
    // Demonstrate network information access
    print('\nNetwork Information:');
    print('- UUID: ${network.uuid}');
    print('- IV Index: ${network.ivIndex}');
    print('- Next unicast: 0x${network.nextUnicastAddress.toRadixString(16)}');
    
    // Show node information
    for (final node in network.nodes.take(3)) { // Show first 3 nodes
      print('- Node: ${node.name} (unicast: 0x${node.unicastAddress.toRadixString(16)})');
    }
    
  } catch (e) {
    print('Error in advanced example: $e');
  }
}

/// Helper function to demonstrate different message types
void demonstrateMessageTypes() {
  print('\n=== Message Type Examples ===');
  
  // Generic On/Off messages
  final genericOnOffGet = Uint8List.fromList([0x82, 0x01]);
  final genericOnOffSet = Uint8List.fromList([0x82, 0x02, 0x01, 0x00]);
  
  // Light HSL messages  
  final lightHslGet = Uint8List.fromList([0x82, 0x6D]);
  final lightHslSet = Uint8List.fromList([0x82, 0x76, 0xFF, 0xFF, 0x00, 0x00, 0x80, 0x00]);
  
  print('Generic On/Off Get: ${_formatMessage(genericOnOffGet)}');
  print('Generic On/Off Set: ${_formatMessage(genericOnOffSet)}');
  print('Light HSL Get: ${_formatMessage(lightHslGet)}');
  print('Light HSL Set: ${_formatMessage(lightHslSet)}');
}

String _formatMessage(Uint8List message) {
  return message.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
}
