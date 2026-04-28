import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String userId;
  final String title;
  final String note;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm — empty means no notification

  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.note,
    required this.date,
    required this.time,
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CalendarEvent(
      id: doc.id,
      userId: d['userId'] ?? '',
      title: d['title'] ?? '',
      note: d['note'] ?? '',
      date: d['date'] ?? '',
      time: d['time'] ?? '',
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'title': title,
        'note': note,
        'date': date,
        'time': time,
      };
}
