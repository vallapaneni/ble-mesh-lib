/// Mesh Data Manager that caches networks locally and manages Firestore watches.
///
/// This class maintains a local cache of mesh networks and automatically
/// manages Firestore listeners to keep the cache up-to-date.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mesh_firestore_manager.dart';
import 'data/mesh_network.dart';

/// Device information from Firestore
class DeviceInfo {
  final String deviceName;
  final String hardwareRevision;
  final String networkType;
  final String networkUuid;
  final DateTime cachedAt;

  const DeviceInfo({
    required this.deviceName,
    required this.hardwareRevision,
    required this.networkType,
    required this.networkUuid,
    required this.cachedAt,
  });

  bool get isOpenNetwork => networkType == 'open';

  /// Creates DeviceInfo from Firestore document data
  factory DeviceInfo.fromFirestore(String deviceName, Map<String, dynamic> data) {
    return DeviceInfo(
      deviceName: deviceName,
      hardwareRevision: data['hwRev'] as String? ?? 'unknown',
      networkType: data['nType'] as String? ?? 'unknown',
      networkUuid: data['nUuid'] as String? ?? '',
      cachedAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'DeviceInfo($deviceName, $networkType, $networkUuid)';
}

/// Manages mesh networks with local caching and automatic Firestore synchronization.
class MeshDataManager {
  final MeshFirestoreManager _firestoreManager;
  final FirebaseFirestore _firestore;
  final String _devicesCollection;
  
  // Local cache of networks
  final Map<String, MeshNetwork> _networksCache = {};
  
  // Local cache of devices
  final Map<String, DeviceInfo> _devicesCache = {};
  
  // Active network watchers
  final Map<String, StreamSubscription<MeshNetwork?>> _networkWatchers = {};
  
  // Stream controllers for external listeners
  final StreamController<Map<String, MeshNetwork>> _networksController = 
      StreamController<Map<String, MeshNetwork>>.broadcast();
  final Map<String, StreamController<MeshNetwork?>> _networkControllers = {};

  MeshDataManager(
    this._firestoreManager,
    this._firestore, {
    String devicesCollection = 'devices',
  }) : _devicesCollection = devicesCollection;

  /// Gets the current cached networks as a map.
  Map<String, MeshNetwork> get cachedNetworks => Map.unmodifiable(_networksCache);

  /// Gets a stream of currently watched networks (from cache, updated by Firestore).
  /// 
  /// This stream only includes networks that are being actively watched via
  /// getNetwork() or watchNetwork() calls.
  Stream<Map<String, MeshNetwork>> get networksStream => _networksController.stream;

  /// Gets a network from cache or starts watching it if not found.
  /// 
  /// Returns immediately with cached data if available, otherwise returns null
  /// but starts watching the network (subsequent calls will return cached data).
  /// 
  /// **Use this when:**
  /// - You know the network should already be cached (from a previous watchNetwork call)
  /// - You need synchronous access to cached data
  /// - You want to check if a network is available without setting up a stream
  /// 
  /// **For reactive updates, prefer watchNetwork() instead.**
  MeshNetwork? getNetwork(String networkId) {
    // Check cache first
    if (_networksCache.containsKey(networkId)) {
      return _networksCache[networkId];
    }

    // Start watching if not already watching
    if (!_networkWatchers.containsKey(networkId)) {
      _startWatchingNetwork(networkId);
    }

    return null; // Will be available in cache after first Firestore response
  }

  /// Gets a stream for a specific network.
  /// 
  /// The stream will emit the current cached value immediately if available,
  /// then emit updates as they come from Firestore.
  /// 
  /// **This is the preferred method for most use cases** as it provides:
  /// - Immediate cached data (if available)
  /// - Real-time updates when network changes
  /// - Automatic Firestore listener management
  /// 
  /// **Usage pattern:**
  /// ```dart
  /// _subscription = dataManager.watchNetwork(networkId).listen((network) {
  ///   if (network != null) {
  ///     // Use network data (initial + updates)
  ///     final meshApi = BleMeshApi(network);
  ///   }
  /// });
  /// ```
  Stream<MeshNetwork?> watchNetwork(String networkId) {
    // Create controller if it doesn't exist
    if (!_networkControllers.containsKey(networkId)) {
      _networkControllers[networkId] = StreamController<MeshNetwork?>.broadcast();
    }

    final controller = _networkControllers[networkId]!;

    // Emit current cached value immediately if available
    if (_networksCache.containsKey(networkId)) {
      // Use Timer to avoid sync emission
      Timer.run(() => controller.add(_networksCache[networkId]));
    }

    // Start watching if not already watching
    if (!_networkWatchers.containsKey(networkId)) {
      _startWatchingNetwork(networkId);
    }

    return controller.stream;
  }

  /// Starts watching a specific network from Firestore.
  void _startWatchingNetwork(String networkId) {
    if (_networkWatchers.containsKey(networkId)) {
      return; // Already watching
    }

    _networkWatchers[networkId] = _firestoreManager.watchNetwork(networkId).listen(
      (network) {
        if (network != null) {
          // Update cache
          _networksCache[networkId] = network;
          
          // Notify network-specific listeners
          _networkControllers[networkId]?.add(network);
          
          // Notify all-networks listeners
          _networksController.add(_networksCache);
        } else {
          // Network was deleted
          _networksCache.remove(networkId);
          
          // Notify network-specific listeners
          _networkControllers[networkId]?.add(null);
          
          // Notify all-networks listeners
          _networksController.add(_networksCache);
          
          // Clean up watchers for deleted network
          _stopWatchingNetwork(networkId);
        }
      },
      onError: (error) {
        print('Error watching network $networkId: $error');
        _networkControllers[networkId]?.addError(error);
      },
    );
  }

  /// Stops watching a specific network.
  void _stopWatchingNetwork(String networkId) {
    _networkWatchers[networkId]?.cancel();
    _networkWatchers.remove(networkId);
    
    // Close and remove controller
    _networkControllers[networkId]?.close();
    _networkControllers.remove(networkId);
  }

  /// Checks if a network is cached locally.
  bool isNetworkCached(String networkId) {
    return _networksCache.containsKey(networkId);
  }

  /// Gets the number of cached networks.
  int get cachedNetworkCount => _networksCache.length;

  /// Gets the number of active network watchers.
  int get activeWatcherCount => _networkWatchers.length;

  // =============================================================================
  // DEVICE MANAGEMENT METHODS
  // =============================================================================

  /// Gets device information by device name.
  /// 
  /// This method follows a three-tier approach:
  /// 1. Check cached devices first (fastest)
  /// 2. Search in cached networks for the device
  /// 3. Query Firestore if not found in cache
  /// 
  /// Returns null if device is not found anywhere.
  Future<DeviceInfo?> getDeviceInfo(String deviceName) async {
    // 1. Check cached devices first
    if (_devicesCache.containsKey(deviceName)) {
      return _devicesCache[deviceName];
    }

    // 2. Search through cached networks
    for (final network in _networksCache.values) {
      for (final node in network.nodes) {
        if (node.name == deviceName) {
          // Create DeviceInfo from cached network data
          final deviceInfo = DeviceInfo(
            deviceName: deviceName,
            hardwareRevision: _extractHardwareRevision(node.name),
            networkType: 'open', // Assume open if found in cached network
            networkUuid: network.uuid,
            cachedAt: DateTime.now(),
          );
          
          // Cache the device info for future use
          _devicesCache[deviceName] = deviceInfo;
          return deviceInfo;
        }
      }
    }

    // 3. Query Firestore if not found in cache
    try {
      final deviceDoc = await _firestore
          .collection(_devicesCollection)
          .doc(deviceName)
          .get();

      if (!deviceDoc.exists) {
        return null;
      }

      final deviceInfo = DeviceInfo.fromFirestore(deviceName, deviceDoc.data()!);
      
      // Cache the device info
      _devicesCache[deviceName] = deviceInfo;
      
      return deviceInfo;
    } catch (e) {
      print('Error querying Firestore for device $deviceName: $e');
      return null;
    }
  }

  /// Checks if a device is cached locally (in device cache or network cache).
  bool isDeviceCached(String deviceName) {
    // Check device cache
    if (_devicesCache.containsKey(deviceName)) {
      return true;
    }

    // Check network cache
    for (final network in _networksCache.values) {
      for (final node in network.nodes) {
        if (node.name == deviceName) {
          return true;
        }
      }
    }

    return false;
  }

  /// Gets all cached devices.
  Map<String, DeviceInfo> get cachedDevices => Map.unmodifiable(_devicesCache);

  /// Gets the number of cached devices.
  int get cachedDeviceCount => _devicesCache.length;

  /// Clears the device cache.
  void clearDeviceCache() {
    _devicesCache.clear();
  }

  /// Extracts hardware revision from node name (can be overridden for custom logic).
  String _extractHardwareRevision(String nodeName) {
    final nameParts = nodeName.split('_');
    for (final part in nameParts) {
      if (part.startsWith('v0p')) {
        return part;
      }
    }
    return 'unknown';
  }

  /// Saves a network to Firestore and updates the local cache.
  Future<void> saveNetwork(MeshNetwork network, {String? networkId}) async {
    await _firestoreManager.saveNetwork(network, networkId: networkId);
    
    // Update local cache immediately (Firestore watcher will also update it)
    final docId = networkId ?? network.uuid;
    _networksCache[docId] = network;
    
    // Notify listeners
    _networkControllers[docId]?.add(network);
    _networksController.add(_networksCache);
  }

  /// Updates a network in Firestore and updates the local cache.
  Future<void> updateNetwork(MeshNetwork network, {String? networkId}) async {
    await _firestoreManager.updateNetwork(network, networkId: networkId);
    
    // Update local cache immediately (Firestore watcher will also update it)
    final docId = networkId ?? network.uuid;
    _networksCache[docId] = network;
    
    // Notify listeners
    _networkControllers[docId]?.add(network);
    _networksController.add(_networksCache);
  }

  /// Deletes a network from Firestore and removes it from the local cache.
  Future<void> deleteNetwork(String networkId) async {
    await _firestoreManager.deleteNetwork(networkId);
    
    // Remove from local cache immediately (Firestore watcher will also remove it)
    _networksCache.remove(networkId);
    
    // Notify listeners
    _networkControllers[networkId]?.add(null);
    _networksController.add(_networksCache);
    
    // Stop watching the deleted network
    _stopWatchingNetwork(networkId);
  }

  /// Pre-loads specific networks into the cache.
  Future<void> preloadNetworks(List<String> networkIds) async {
    for (final networkId in networkIds) {
      if (!_networksCache.containsKey(networkId)) {
        _startWatchingNetwork(networkId);
      }
    }
  }

  /// Clears the local cache and stops all watchers.
  void clearCache() {
    // Stop all network watchers
    for (final subscription in _networkWatchers.values) {
      subscription.cancel();
    }
    _networkWatchers.clear();
    
    // Close all controllers
    for (final controller in _networkControllers.values) {
      controller.close();
    }
    _networkControllers.clear();
    
    // Clear caches
    _networksCache.clear();
    _devicesCache.clear();
    
    // Notify listeners of empty cache
    _networksController.add(_networksCache);
  }

  /// Disposes of all resources.
  void dispose() {
    clearCache();
    _networksController.close();
  }

  /// Gets all networks as a list (one-time read, bypasses cache).
  /// 
  /// This method is provided for compatibility but it's generally better
  /// to use the cache-based methods or streams.
  Future<List<MeshNetwork>> getAllNetworks() async {
    return await _firestoreManager.getAllNetworks();
  }

  /// Gets a specific network by ID (one-time read, bypasses cache).
  /// 
  /// This method is provided for compatibility but it's generally better
  /// to use getNetwork() which returns cached data or watchNetwork() for streams.
  Future<MeshNetwork?> getNetworkFromFirestore(String networkId) async {
    return await _firestoreManager.getNetwork(networkId);
  }

  /// Listens to all networks directly from Firestore (bypasses cache).
  /// 
  /// This method is provided for compatibility but it's generally better
  /// to use networksStream which includes cached data.
  Stream<List<MeshNetwork>> watchNetworksFromFirestore() {
    return _firestoreManager.watchNetworks();
  }

  /// Listens to a specific network directly from Firestore (bypasses cache).
  /// 
  /// This method is provided for compatibility but it's generally better
  /// to use watchNetwork() which includes cached data.
  Stream<MeshNetwork?> watchNetworkFromFirestore(String networkId) {
    return _firestoreManager.watchNetwork(networkId);
  }
}
