class ImageModel {
  final String id;
  final String name;
  final String tag;
  final int size;
  final DateTime created;

  ImageModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.size,
    required this.created,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    // RepoTags is a list
    final List<dynamic>? tags = json['RepoTags'];

    String name = "";
    String tag = "";

    if (tags != null && tags.isNotEmpty) {
      final repo = tags.first;
      final parts = repo.split(':');

      name = parts[0];
      tag = parts.length > 1 ? parts[1] : "";
    }

    return ImageModel(
      id: json['Id'],
      name: name,
      tag: tag,
      size: json['Size'],
      created: DateTime.fromMillisecondsSinceEpoch(json['Created'] * 1000),
    );
  }
}
