import 'dart:io';
import 'package:alarm/alarm.dart';

class NotificationService {
  static Future<void> init() async {
    await Alarm.init();
    await Alarm.setWarningNotificationOnKill(
      'Rappel annulé',
      "L'application a été fermée avant le déclenchement du rappel.",
    );
  }

  static int _id(String id) => id.hashCode & 0x7FFFFFFF;

  static Future<void> schedule(
      String id, String title, String note, String date, String time) async {
    if (time.isEmpty) return;

    final dateParts = date.split('-');
    final timeParts = time.split(':');
    if (dateParts.length != 3 || timeParts.length != 2) return;

    final dateTime = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    if (dateTime.isBefore(DateTime.now())) return;

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: _id(id),
        dateTime: dateTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: false,
        vibrate: true,
        warningNotificationOnKill: Platform.isIOS,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 15),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: title,
          body: note.isEmpty ? 'Rappel' : note,
          stopButton: 'Arrêter',
        ),
      ),
    );
  }

  static Future<void> cancel(String id) => Alarm.stop(_id(id));
}
