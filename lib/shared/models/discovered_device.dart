/// Represents a device discovered via mDNS service discovery.
class DiscoveredDevice {
  final String name;
  final String host;
  final int port;
  final String? serviceName;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
    this.serviceName,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'serviceName': serviceName,
  };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      serviceName: json['serviceName'] as String?,
    );
  }

  @override
  String toString() =>
      'DiscoveredDevice(name: $name, host: $host, port: $port)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredDevice &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}
