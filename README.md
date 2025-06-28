# BLE Mesh Library

A comprehensive Bluetooth Mesh library for Dart that provides cryptography, protocol layers, and data models for Bluetooth Mesh applications.

## Features

- **Protocol Implementation**: Complete implementation of Bluetooth Mesh protocol stack
  - Network Layer: Encryption, obfuscation, and routing
  - Transport Layer: Segmentation and reassembly
  - Access Layer: High-level message handling
- **Cryptographic Utilities**: Full suite of mesh security functions
- **Data Models**: Comprehensive models for mesh networks, nodes, and configuration
- **High-Level API**: Simple interface for common mesh operations

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  ble_mesh_lib:
    path: packages/ble-mesh-lib
```

## Usage

### Basic Usage

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

The library is organized into three main layers:

### Data Layer (`lib/src/data/`)
- `MeshNetwork`: Top-level network representation
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
