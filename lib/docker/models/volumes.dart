class VolumeModel {
  final String name;
  final String driver;
  final DateTime createdAt;
  final Map<String, dynamic>? labels;

  VolumeModel({
    required this.name,
    required this.driver,
    required this.createdAt,
    this.labels,
  });

  factory VolumeModel.fromJson(Map<String, dynamic> json) {
    return VolumeModel(
      name: json['Name'] as String,
      driver: json['Driver'] as String,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
      labels: json['Labels'] as Map<String, dynamic>?,
    );
  }
}
