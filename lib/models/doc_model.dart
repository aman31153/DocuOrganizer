enum DocType { pdf, ppt, doc, xls, txt, image, other, video, folder }

class DocModel {
  final String id;
  final String name;
  final DocType type;
  final double size; // in MB
  final DateTime uploadDate;
  final String url;
  final String folderId;
  final bool isStarred;
  final bool isDeleted;
  final DateTime? lastOpenedAt;

  DocModel({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.uploadDate,
    required this.url,
    required this.folderId,
    this.isStarred = false,
    this.isDeleted = false,
    this.lastOpenedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'size': size,
      'uploadDate': uploadDate.toIso8601String(),
      'url': url,
      'folderId': folderId,
      'isStarred': isStarred,
      'isDeleted': isDeleted,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
    };
  }

  factory DocModel.fromMap(Map<String, dynamic> map) {
    DateTime date;
    if (map['uploadDate'] != null) {
      date = DateTime.tryParse(map['uploadDate'].toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    DateTime? lastOpened;
    if (map['lastOpenedAt'] != null) {
      lastOpened = DateTime.tryParse(map['lastOpenedAt'].toString());
    }

    return DocModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: DocType.values[map['type'] ?? 5],
      size: (map['size'] ?? 0.0).toDouble(),
      uploadDate: date,
      url: map['url'] ?? '',
      folderId: map['folderId'] ?? '',
      isStarred: map['isStarred'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      lastOpenedAt: lastOpened,
    );
  }
}
