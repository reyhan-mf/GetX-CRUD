class TaskModel {
  final int id;
  final String title;
  final String description;
  final DateTime dateTime;
  final DateTime createTime;
  final bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.createTime,
    this.isCompleted = false,
  });

  Map<String, Object?> toJSON() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'createTime': createTime.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0, // Convert bool to int for SQLite
    };
  }

  factory TaskModel.fromJSON(Map<dynamic, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: DateTime.parse(json['dateTime']),
      createTime: DateTime.parse(json['createTime']),
      isCompleted: json['isCompleted'] == 1, // Convert int to bool from SQLite
    );
  }
}
