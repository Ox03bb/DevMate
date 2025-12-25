class Ports {
  final String ip;
  final String privatePort;
  final String publicPort;
  final String type;
  Ports({
    required this.ip,
    required this.privatePort,
    required this.publicPort,
    required this.type,
  });

  factory Ports.fromJson(Map<String, dynamic> json) {
    return Ports(
      ip: json['ip'] as String,
      privatePort: json['privatePort'] as String,
      publicPort: json['publicPort'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'privatePort': privatePort,
      'publicPort': publicPort,
      'type': type,
    };
  }
}

class ContainerModel {
  final String id;
  final String name;
  final Map<String, String>? labels;
  final String image;
  final String state;
  final DateTime createdAt;
  final List<Ports>? ports;

  ContainerModel({
    required this.id,
    required this.name,
    this.labels,
    required this.image,
    required this.state,
    required this.createdAt,
    this.ports,
  });

  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    return ContainerModel(
      id: json['Id'] as String,
      name: json['Names'][0].substring(1) as String? ?? '',
      image: json['Image'] as String? ?? '',
      labels:
          (json['Labels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as String),
          ) ??
          {},
      state: json['State'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ports: (json['ports'] as List<dynamic>?)
          ?.map((port) => Ports.fromJson(port as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'state': state,
      'createdAt': createdAt.toIso8601String(),
      'ports': ports?.map((port) => port.toJson()).toList(),
    };
  }
}
