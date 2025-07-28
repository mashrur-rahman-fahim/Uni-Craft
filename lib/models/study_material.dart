// Study Material Model
class StudyMaterial {
  final String id;
  final String name;
  final String url;
  final String uploadDate;
  final String type; // 'image', 'file', 'link'
  final String uploaderUid;
  final String? description;
  final int? fileSize;
  final String? groupCode;
  final String? subject;
  final String? uploaderName;

  StudyMaterial({
    required this.id,
    required this.name,
    required this.url,
    required this.uploadDate,
    required this.type,
    required this.uploaderUid,
    this.description,
    this.fileSize,
    this.groupCode,
    this.subject,
    this.uploaderName,
  });

  factory StudyMaterial.fromFirestore(Map<String, dynamic> data, String documentId) {
    return StudyMaterial(
      id: documentId,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      uploadDate: data['uploadDate'] ?? '',
      type: data['type'] ?? '',
      uploaderUid: data['uploaderUid'] ?? '',
      description: data['description'],
      fileSize: data['fileSize'],
      groupCode: data['groupCode'],
      subject: data['subject'],
      uploaderName: data['uploaderName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'url': url,
      'uploadDate': uploadDate,
      'type': type,
      'uploaderUid': uploaderUid,
      'description': description,
      'fileSize': fileSize,
      'groupCode': groupCode,
      'subject': subject,
      'uploaderName': uploaderName,
    };
  }

  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
  bool get isLink => type == 'link';
}
