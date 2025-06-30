/// Mesh Scanner that discovers mesh proxy devices and automatically watches networks.
///
/// This class integrates BLE scanning with the mesh data manager to:
/// 1. Scan for devices advertising Mesh Proxy service
/// 2. Use MeshDataManager's three-tier device lookup (device cache -> network cache -> Firestore)
/// 3. Automatically watch networks for "open" devices via MeshDataManager
/// 4. Provide real-time updates of discovered networks and devices
///
/// **Architecture Note:**
/// - All operations go through MeshDataManager (complete encapsulation)
/// - Three-tier caching: device cache -> network cache -> Firestore
/// - Minimal Firestore requests through intelligent caching
/// - Automatic network watching for efficient real-time updates

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ble_utils/ble_utils.dart';
import 'mesh_data_manager.dart';
import 'data/mesh_network.dart';

/// Information about a discovered mesh device
class DiscoveredMeshDevice {
  final String deviceName;
  final String deviceId;
  final int rssi;
  final String hardwareRevision;
  final String networkType;
  final String networkUuid;
  final DateTime discoveredAt;

  const DiscoveredMeshDevice({
    required this.deviceName,
    required this.deviceId,
    required this.rssi,
    required this.hardwareRevision,
    required this.networkType,
    required this.networkUuid,
    required this.discoveredAt,
  });

  bool get isOpenNetwork => networkType == 'open';

  @override
  String toString() => 'DiscoveredMeshDevice($deviceName, RSSI: $rssi, Network: $networkUuid)';
}

/// Information about a discovered mesh network with its devices
class DiscoveredMeshNetwork {
  final String networkUuid;
  final String networkName;
  final MeshNetwork? networkData;
  final List<DiscoveredMeshDevice> devices;
  final DateTime lastSeen;

  const DiscoveredMeshNetwork({
    required this.networkUuid,
    required this.networkName,
    required this.networkData,
    required this.devices,
    required this.lastSeen,
  });

  int get deviceCount => devices.length;
  int get bestRssi => devices.isEmpty ? -100 : devices.map((d) => d.rssi).reduce((a, b) => a > b ? a : b);

  @override
  String toString() => 'DiscoveredMeshNetwork($networkName, ${devices.length} devices)';
}

/// Mesh Scanner that discovers proxy devices and manages network watching
class MeshScanner {
  final MeshDataManager _dataManager;
  final BleManager _bleManager;

  // Internal state
  final Map<String, DiscoveredMeshDevice> _discoveredDevices = {};
  final Map<String, DiscoveredMeshNetwork> _discoveredNetworks = {};
  final Set<String> _watchedNetworks = {};

  // Stream controllers
  final StreamController<List<DiscoveredMeshDevice>> _devicesController = 
      StreamController<List<DiscoveredMeshDevice>>.broadcast();
  final StreamController<List<DiscoveredMeshNetwork>> _networksController = 
      StreamController<List<DiscoveredMeshNetwork>>.broadcast();

  // Subscriptions
  StreamSubscription<ScannedBleDevice>? _scanSubscription;
  final Map<String, StreamSubscription<MeshNetwork?>> _networkSubscriptions = {};

  MeshScanner(this._dataManager) : _bleManager = BleManager();

  /// Stream of discovered mesh devices
  Stream<List<DiscoveredMeshDevice>> get devicesStream => _devicesController.stream;

  /// Stream of discovered mesh networks with their devices
  Stream<List<DiscoveredMeshNetwork>> get networksStream => _networksController.stream;

  /// Gets currently discovered devices
  List<DiscoveredMeshDevice> get discoveredDevices => _discoveredDevices.values.toList();

  /// Gets currently discovered networks
  List<DiscoveredMeshNetwork> get discoveredNetworks => _discoveredNetworks.values.toList();

  /// Initializes the scanner and BLE manager
  Future<void> initialize() async {
    await _bleManager.initialize();
  }

  /// Starts scanning for mesh proxy devices
  Future<void> startScanning() async {
    if (_scanSubscription != null) {
      await stopScanning();
    }

    // Configure scan to look for Mesh Proxy service
    final config = BleScanConfig(
      serviceUuids: [MeshProxyService.serviceUuid],
      scanMode: ScanMode.lowLatency,
    );

    await _bleManager.scanModule.startScan(config: config);

    // Listen to individual device discoveries
    _scanSubscription = _bleManager.scanModule.deviceStream.listen(
      _onDeviceDiscovered,
      onError: (error) {
        print('Error during mesh scanning: $error');
      },
    );
  }

  /// Stops scanning for devices
  Future<void> stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleManager.scanModule.stopScan();
  }

  /// Handles discovery of a new BLE device
  Future<void> _onDeviceDiscovered(ScannedBleDevice device) async {
    try {
      // Check if device advertises Mesh Proxy service
      final hasProxyService = device.serviceUuids.contains(MeshProxyService.serviceUuid);
      if (!hasProxyService) {
        return; // Not a mesh proxy device
      }

      print('🔍 Discovering device: ${device.name}');

      // Get device information via data manager (uses three-tier caching)
      final deviceInfo = await _dataManager.getDeviceInfo(device.name);
      
      if (deviceInfo == null) {
        print('❌ Device ${device.name} not found in cache or Firestore');
        return;
      }

      if (deviceInfo.networkUuid.isEmpty) {
        print('❌ Device ${device.name} has no network UUID');
        return;
      }

      print('✅ Found device ${device.name} -> network ${deviceInfo.networkUuid}');

      // Create discovered device
      final discoveredDevice = DiscoveredMeshDevice(
        deviceName: device.name,
        deviceId: device.id,
        rssi: device.rssi,
        hardwareRevision: deviceInfo.hardwareRevision,
        networkType: deviceInfo.networkType,
        networkUuid: deviceInfo.networkUuid,
        discoveredAt: DateTime.now(),
      );

      // Update devices cache
      _discoveredDevices[device.id] = discoveredDevice;

      // If it's an open network, start watching it (via data manager)
      if (discoveredDevice.isOpenNetwork && !_watchedNetworks.contains(deviceInfo.networkUuid)) {
        await _startWatchingNetwork(deviceInfo.networkUuid);
      }

      // Update network information
      await _updateNetworkInfo(discoveredDevice);

      // Notify listeners
      _devicesController.add(_discoveredDevices.values.toList());

    } catch (e) {
      print('❌ Error processing discovered device ${device.name}: $e');
    }
  }

  /// Starts watching a network and its updates
  Future<void> _startWatchingNetwork(String networkUuid) async {
    if (_watchedNetworks.contains(networkUuid)) {
      return; // Already watching
    }

    _watchedNetworks.add(networkUuid);

    // Start watching the network via data manager
    _networkSubscriptions[networkUuid] = _dataManager.watchNetwork(networkUuid).listen(
      (network) {
        _updateNetworkData(networkUuid, network);
      },
      onError: (error) {
        print('Error watching network $networkUuid: $error');
      },
    );
  }

  /// Updates network information with new device or network data
  Future<void> _updateNetworkInfo(DiscoveredMeshDevice device) async {
    final networkUuid = device.networkUuid;
    
    // Get current network data from data manager
    final networkData = _dataManager.getNetwork(networkUuid);
    
    // Get or create network discovery info
    var networkInfo = _discoveredNetworks[networkUuid];
    if (networkInfo == null) {
      networkInfo = DiscoveredMeshNetwork(
        networkUuid: networkUuid,
        networkName: networkData?.name ?? 'Unknown Network',
        networkData: networkData,
        devices: [],
        lastSeen: device.discoveredAt,
      );
    }

    // Update devices list (replace existing device with same ID)
    final updatedDevices = List<DiscoveredMeshDevice>.from(networkInfo.devices);
    updatedDevices.removeWhere((d) => d.deviceId == device.deviceId);
    updatedDevices.add(device);

    // Create updated network info
    final updatedNetworkInfo = DiscoveredMeshNetwork(
      networkUuid: networkUuid,
      networkName: networkData?.name ?? networkInfo.networkName,
      networkData: networkData,
      devices: updatedDevices,
      lastSeen: device.discoveredAt,
    );

    _discoveredNetworks[networkUuid] = updatedNetworkInfo;
    _networksController.add(_discoveredNetworks.values.toList());
  }

  /// Updates network data when received from Firestore
  void _updateNetworkData(String networkUuid, MeshNetwork? networkData) {
    final networkInfo = _discoveredNetworks[networkUuid];
    if (networkInfo == null) return;

    // Update network info with new data
    final updatedNetworkInfo = DiscoveredMeshNetwork(
      networkUuid: networkUuid,
      networkName: networkData?.name ?? networkInfo.networkName,
      networkData: networkData,
      devices: networkInfo.devices,
      lastSeen: networkInfo.lastSeen,
    );

    _discoveredNetworks[networkUuid] = updatedNetworkInfo;
    _networksController.add(_discoveredNetworks.values.toList());
  }

  /// Clears all discovered devices and networks
  void clearDiscoveredDevices() {
    _discoveredDevices.clear();
    _discoveredNetworks.clear();
    _devicesController.add([]);
    _networksController.add([]);
  }

  /// Disposes of the scanner and cleans up resources
  Future<void> dispose() async {
    await stopScanning();
    
    // Cancel network subscriptions
    for (final subscription in _networkSubscriptions.values) {
      await subscription.cancel();
    }
    _networkSubscriptions.clear();
    _watchedNetworks.clear();

    // Close controllers
    await _devicesController.close();
    await _networksController.close();

    // Clear data
    _discoveredDevices.clear();
    _discoveredNetworks.clear();
  }
}
