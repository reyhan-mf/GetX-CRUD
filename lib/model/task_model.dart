class TaskModel {
  String? id;
  String title;
  String description;
  DateTime dateTime;
  String? userId;
  int? createdAt;
  int? updatedAt;

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  // Convert dari Realtime Database
  factory TaskModel.fromRealtimeDatabase(String key, Map<dynamic, dynamic> data) {
    return TaskModel(
      id: key,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dateTime: DateTime.fromMillisecondsSinceEpoch(data['dateTime'] ?? 0),
      userId: data['userId'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  // Convert ke Map untuk Realtime Database
  Map<String, dynamic> toRealtimeDatabase() {
    return {
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'userId': userId,
    };
  }

  // Convert dari SQLite (untuk backward compatibility)
  factory TaskModel.fromSqfliteDatabase(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime: DateTime.parse(map['dateTime']),
    );
  }

  // Convert ke SQLite Map (untuk backward compatibility)
  Map<String, dynamic> toSqfliteDatabase() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
    };
  }
}