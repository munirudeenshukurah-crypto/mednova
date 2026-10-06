import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
  NotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Alarm.init();

    _initialized = true;
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    await initialize();

    final DateTime now = DateTime.now();

    if (dateTime.isBefore(now)) {
      return;
    }

    final AlarmSettings alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,

      // null = use the phone's default alarm sound.
      assetAudioPath: null,

      // Keep ringing until the user stops it.
      loopAudio: true,

      // Keep vibrating while the alarm is ringing.
      vibrate: true,

      // Show the alarm even when the app is not open.
      warningNotificationOnKill: Platform.isIOS,

      // Wake the Android screen and show the alarm.
      androidFullScreenIntent: true,

      // Keep the alarm active as an Android alarm.
      androidStopAlarmOnTermination: false,

      // Do not allow another medication alarm to interrupt
      // an already ringing alarm.
      allowAlarmOverlap: false,

      // Use the alarm volume.
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        fadeDuration: const Duration(seconds: 1),
        volumeEnforced: true,
      ),

      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'STOP ALARM',
        icon: 'ic_launcher',
        iconColor: const Color(0xFF6C3CE9),

        // Swiping the notification away should NOT silently
        // stop a medication alarm.
        androidStopAlarmOnDismiss: false,
      ),

      // Send the ID as payload so we can identify the alarm later.
      payload: id.toString(),
    );

    await Alarm.set(
      alarmSettings: alarmSettings,
    );
  }

  Future<void> cancelReminder(int id) async {
    await initialize();

    await Alarm.stop(id);
  }

  Future<void> cancelAllReminders() async {
    await initialize();

    await Alarm.stopAll();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    final DateTime alarmTime =
    DateTime.now().add(const Duration(seconds: 2));

    final AlarmSettings alarmSettings = AlarmSettings(
      id: id,
      dateTime: alarmTime,
      assetAudioPath: null,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      allowAlarmOverlap: false,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        fadeDuration: const Duration(seconds: 1),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'STOP ALARM',
        icon: 'ic_launcher',
        iconColor: const Color(0xFF6C3CE9),
        androidStopAlarmOnDismiss: false,
      ),
      payload: id.toString(),
    );

    await Alarm.set(
      alarmSettings: alarmSettings,
    );
  }

  Future<void> testAlarm() async {
    await showNotification(
      id: 999999,
      title: 'MedNova Medication Reminder',
      body: 'Time to take your medication.',
    );
  }
}
