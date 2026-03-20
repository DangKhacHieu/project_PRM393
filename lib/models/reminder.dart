class Reminder {
  final int? id;
  final String title;
  final String content;
  final String time;
  final int isDone;
  final String priority;
  final String category;
  final int isDeleted;

  Reminder({
    this.id,
    required this.title,
    required this.content,
    required this.time,
    this.isDone = 0,
    this.priority = 'Medium',
    this.category = 'Chung',
    this.isDeleted = 0,
  });

  // Chuyển sang Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'time': time,
      'isDone': isDone,
      'priority': priority,
      'category': category,
      'isDeleted': isDeleted,
    };
  }

  // Chuyển từ Map về lại Object Dart
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      time: map['time'] ?? '',
      isDone: map['isDone'] ?? 0,
      priority: map['priority'] ?? 'Medium',
      category: map['category'] ?? 'Chung',
      isDeleted: map['isDeleted'] ?? 0,
    );
  }
}