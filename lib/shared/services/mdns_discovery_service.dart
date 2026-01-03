import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:devmate/shared/models/discovered_device.dart';

/// Service for discovering devices on the local network using mDNS.
class MdnsDiscoveryService {
  final MDnsClient _client = MDnsClient();
  bool _isRunning = false;

  /// Default service type for DevMate discovery.
  /// You can customize this based on what service you want to discover.
  static const String defaultServiceType = '_devmate._tcp';

  /// Discovers devices advertising the specified service type on the local network.
  ///
  /// [serviceType] - The mDNS service type to search for (e.g., '_http._tcp', '_devmate._tcp').
  /// [timeout] - How long to search for devices before returning results.
  ///
  /// Returns a list of discovered devices.
  Future<List<DiscoveredDevice>> discoverDevices({
    String serviceType = defaultServiceType,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final devices = <DiscoveredDevice>[];
    final seenHosts = <String>{};

    try {
      await _client.start();
      _isRunning = true;

      // Query for PTR records to find service instances
      await for (final PtrResourceRecord ptr
          in _client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              )
              .timeout(timeout, onTimeout: (sink) => sink.close())) {
        // For each PTR record, look up the SRV record to get host and port
        await for (final SrvResourceRecord srv
            in _client
                .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: (sink) => sink.close(),
                )) {
          // Look up the IP address for the host
          await for (final IPAddressResourceRecord ip
              in _client
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target),
                  )
                  .timeout(
                    const Duration(seconds: 2),
                    onTimeout: (sink) => sink.close(),
                  )) {
            final hostKey = '${ip.address.address}:${srv.port}';
            if (!seenHosts.contains(hostKey)) {
              seenHosts.add(hostKey);

              // Extract a friendly name from the PTR domain name
              String deviceName = _extractDeviceName(
                ptr.domainName,
                serviceType,
              );

              devices.add(
                DiscoveredDevice(
                  name: deviceName,
                  host: ip.address.address,
                  port: srv.port,
                  serviceName: ptr.domainName,
                ),
              );
            }
          }
        }
      }
    } on TimeoutException {
      // Timeout is expected, we just return whatever we found
    } catch (e) {
      // Log error but don't throw - return whatever devices we found
      print('mDNS discovery error: $e');
    } finally {
      await stop();
    }

    return devices;
  }

  /// Discovers devices with a stream-based approach for real-time updates.
  ///
  /// This is useful for showing devices as they are discovered.
  Stream<DiscoveredDevice> discoverDevicesStream({
    String serviceType = defaultServiceType,
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    final seenHosts = <String>{};

    try {
      await _client.start();
      _isRunning = true;

      await for (final PtrResourceRecord ptr
          in _client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              )
              .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv
            in _client
                .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: (sink) => sink.close(),
                )) {
          await for (final IPAddressResourceRecord ip
              in _client
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target),
                  )
                  .timeout(
                    const Duration(seconds: 2),
                    onTimeout: (sink) => sink.close(),
                  )) {
            final hostKey = '${ip.address.address}:${srv.port}';
            if (!seenHosts.contains(hostKey)) {
              seenHosts.add(hostKey);

              String deviceName = _extractDeviceName(
                ptr.domainName,
                serviceType,
              );

              yield DiscoveredDevice(
                name: deviceName,
                host: ip.address.address,
                port: srv.port,
                serviceName: ptr.domainName,
              );
            }
          }
        }
      }
    } on TimeoutException {
      // Expected timeout
    } catch (e) {
      print('mDNS discovery stream error: $e');
    } finally {
      await stop();
    }
  }

  /// Extracts a friendly device name from the mDNS domain name.
  String _extractDeviceName(String domainName, String serviceType) {
    // Domain name is typically: "DeviceName._service._protocol.local"
    // We want to extract just "DeviceName"
    String name = domainName;

    // Remove the service type suffix if present
    if (name.endsWith('.local')) {
      name = name.substring(0, name.length - 6);
    }
    if (name.endsWith(serviceType)) {
      name = name.substring(0, name.length - serviceType.length);
    }
    // Remove trailing dot if present
    if (name.endsWith('.')) {
      name = name.substring(0, name.length - 1);
    }

    // If name is empty or just dots, use a default
    if (name.isEmpty || name == '.') {
      name = 'Unknown Device';
    }

    return name;
  }

  /// Stops the mDNS client.
  Future<void> stop() async {
    if (_isRunning) {
      _client.stop();
      _isRunning = false;
    }
  }

  /// Disposes of resources.
  void dispose() {
    stop();
  }
}
