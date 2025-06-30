# BLE Mesh Library

A comprehensive Bluetooth Mesh library for Dart that provides cryptography, protocol layers, data models, and device discovery for Bluetooth Mesh applications.

## Features

- **Protocol Implementation**: Complete implementation of Bluetooth Mesh protocol stack
  - Network Layer: Encryption, obfuscation, and routing
  - Transport Layer: Segmentation and reassembly
  - Access Layer: High-level message handling
- **Cryptographic Utilities**: Full suite of mesh security functions
- **Data Models**: Comprehensive models for mesh networks, nodes, and configuration
- **High-Level API**: Simple interface for common mesh operations
- **🆕 Firestore Integration**: Persistent network storage with local caching
- **🆕 Device Discovery**: Automatic BLE scanning and mesh proxy device discovery
- **🆕 Three-Tier Caching**: Device cache → Network cache → Firestore for optimal performance

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  ble_mesh_lib:
    path: packages/ble-mesh-lib
  cloud_firestore: ^4.17.3  # Required for Firestore integration
```

## Usage

### Quick Start with Device Discovery

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ble_mesh_lib/ble_mesh_lib.dart';

// 1. Initialize the library with Firestore
final meshLib = BleMeshLibInitializer.initialize(
  FirebaseFirestore.instance,
  networksCollection: 'mesh_networks',
  devicesCollection: 'devices',
);

// 2. Initialize and start scanning for mesh devices
await meshLib.scanner.initialize();
await meshLib.scanner.startScanning();

// 3. Listen for discovered devices and networks
meshLib.scanner.devicesStream.listen((devices) {
  for (final device in devices) {
    print('Found device: ${device.deviceName}');
    print('Signal: ${device.rssi} dBm');
    print('Network: ${device.networkUuid}');
  }
});

meshLib.scanner.networksStream.listen((networks) {
  for (final network in networks) {
    print('Network: ${network.networkName}');
    print('Devices: ${network.deviceCount}');
    
    // Network data is automatically loaded from Firestore
    if (network.networkData != null) {
      final meshApi = BleMeshApi(network.networkData!);
      // Ready to send mesh messages!
    }
  }
});
```

### Manual Network Operations

```dart
// Get data manager for manual network operations
final dataManager = meshLib.dataManager;

// Watch a specific network (recommended)
dataManager.watchNetwork('network-uuid').listen((network) {
  if (network != null) {
    final meshApi = BleMeshApi(network);
    // Use the API for mesh operations
  }
});

// Get cached network (if already watched)
final network = dataManager.getNetwork('network-uuid');
if (network != null) {
  final meshApi = BleMeshApi(network);
}
```

### Basic Protocol Usage

### Basic Protocol Usage

```dart
import 'package:ble_mesh_lib/ble_mesh_lib.dart';

// Load or create a mesh network
final network = MeshNetworkJson.fromJsonString(jsonString);

// Create API instance
final meshApi = BleMeshApi(network);

// Send a model message
final modelMessage = Uint8List.fromList([0x59, 0x00, 0x06, 0x00, 0xe0, 0x01]);
final networkPdu = await meshApi.sendModelMessage(
  modelMessage: modelMessage,
  src: 0x7F06,
  dst: 0x000C,
  appIdx: 0,
  seq: meshApi.getNextSequenceNumber(),
);
```

### Device Lookup with Three-Tier Caching

```dart
// The data manager uses intelligent caching:
// 1. Check device cache (fastest)
// 2. Check network cache (fast) 
// 3. Query Firestore (slower, then cached)

final deviceInfo = await dataManager.getDeviceInfo('device-name');
if (deviceInfo != null) {
  print('Hardware: ${deviceInfo.hardwareRevision}');
  print('Network: ${deviceInfo.networkUuid}');
  print('Type: ${deviceInfo.networkType}');
}
```

### Advanced Usage

For advanced use cases, you can directly use the protocol layers:

```dart
import 'package:ble_mesh_lib/ble_mesh_lib.dart';

// Direct access to protocol layers
final networkPdu = await createNetworkPduFromModelMessage(
  modelMessage: modelMessage,
  network: network,
  appIdx: appIdx,
  seq: seq,
  src: src,
  dst: dst,
  ttl: ttl,
);
```

## Architecture

The library is organized into multiple layers:

### Device Discovery & Caching Layer
- **MeshScanner**: BLE device discovery with Mesh Proxy service detection
- **MeshDataManager**: Three-tier caching system (device cache → network cache → Firestore)
- **BleMeshLibInitializer**: Centralized initialization and configuration

### Firestore Integration Layer
- **MeshFirestoreManager**: Low-level Firestore operations (internal)
- **DeviceInfo**: Device metadata and network association
- Automatic network watching for "open" devices

### Data Layer (`lib/src/data/`)
- `MeshNetwork`: Top-level network representation with Firestore serialization
- `MeshNode`: Individual mesh node
- `MeshElement`: Node elements and models
- `MeshNetKey`/`MeshAppKey`: Security keys
- `MeshGroup`/`MeshScene`: Network organization

### Protocol Layer (`lib/src/protocol/`)
- `mesh_access_layer.dart`: High-level message creation
- `mesh_transport_layer.dart`: Transport encryption/decryption
- `mesh_network_layer.dart`: Network encryption/obfuscation
- `mesh_crypto_utils.dart`: Core cryptographic functions

### API Layer (`lib/src/`)
- `mesh_api.dart`: High-level public API
- `mesh_constants.dart`: Protocol constants

## Data Structure

### Firestore Collections

**Networks Collection (`mesh_networks`):**
```json
{
  "network-uuid": {
    "name": "My Mesh Network",
    "netKeys": [...],
    "appKeys": [...],
    "nodes": [...],
    "ivIndex": 0,
    "timestamp": "2025-06-30T10:30:00.000Z"
  }
}
```

**Devices Collection (`devices`):**
```json
{
  "device-name": {
    "hwRev": "v0p8",
    "nType": "open",
    "nUuid": "03c30e9558df9e73100d4f967fd84c69"
  }
}
```

## Examples

- **`simple_scanner_example.dart`**: Basic device discovery and network watching
- **`scanning_example.dart`**: Comprehensive example with caching and statistics  
- **`flutter_scanner_example.dart`**: Complete Flutter app with UI integration
- **`firestore_example.dart`**: Manual Firestore operations and network management

## Testing

Run tests with:

```bash
cd packages/ble-mesh-lib
dart test
```

## Compliance

This library implements the Bluetooth Mesh specifications:
- Mesh Profile v1.0.1
- Mesh Model v1.0.1

## License

See LICENSE file for details.
