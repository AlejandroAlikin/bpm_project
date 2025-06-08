import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import '../design/colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  List<bool> _selectedDays = List.generate(7, (index) => false);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _createNotificationChannel();
  }

  Future<void> _testNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'pressure_reminder_channel',
      'Напоминания об измерениях',
      channelDescription: 'Напоминания о необходимости измерить давление',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'Тестовое уведомление',
      'Проверка работы уведомлений',
      platformChannelSpecifics,
    );
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pressure_reminder_channel',
      'Напоминания об измерениях',
      description: 'Напоминания о необходимости измерить давление',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    await _loadNotificationSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      _selectedTime = TimeOfDay(
        hour: prefs.getInt('notificationHour') ?? 9,
        minute: prefs.getInt('notificationMinute') ?? 0,
      );
      _selectedDays = List.generate(7, (index) => prefs.getBool('notificationDay$index') ?? false);
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setInt('notificationHour', _selectedTime.hour);
    await prefs.setInt('notificationMinute', _selectedTime.minute);
    for (int i = 0; i < 7; i++) {
      await prefs.setBool('notificationDay$i', _selectedDays[i]);
    }
  }

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) return false;

      final bool? granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('Permission error: $e');
      return false;
    }
  }

  Future<void> _scheduleNotifications() async {
    await _cancelAllNotifications();
    if (!_notificationsEnabled) return;

    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      setState(() => _notificationsEnabled = false);
      return;
    }

    for (int i = 0; i < 7; i++) {
      if (_selectedDays[i]) {
        await _scheduleDailyNotification(i);
        print(i);
      }
    }
  }

  Future<void> _scheduleDailyNotification(int dayIndex) async {
    try {
      final now = tz.TZDateTime.now(tz.local);

      // Дни недели в Dart: 1 = Monday, 7 = Sunday
      int targetWeekday = dayIndex + 1; // Преобразуем индекс (0-6) в weekday (1-7)

      // Находим следующую дату с нужным днем недели
      var scheduledDate = _nextWeekdayDate(now, targetWeekday, _selectedTime);

      debugPrint('Scheduling notification for: $scheduledDate (weekday: ${scheduledDate.weekday})');

      const androidDetails = AndroidNotificationDetails(
        'pressure_reminder_channel',
        'Напоминания об измерениях',
        channelDescription: 'Напоминания о необходимости измерить давление',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        dayIndex, // ID уведомления
        'Время измерить давление',
        'Не забудьте измерить давление и внести данные в приложение',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      debugPrint('Notification scheduled successfully for weekday $targetWeekday');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  tz.TZDateTime _nextWeekdayDate(tz.TZDateTime now, int weekday, TimeOfDay time) {
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Пока не найдем нужный день недели
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Если время уже прошло сегодня, переносим на следующую неделю
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  Future<void> _cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
      await _saveNotificationSettings();
      await _scheduleNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Напоминания',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            _buildNotificationToggle(),
            const SizedBox(height: 24),
            _buildTimePicker(),
            const SizedBox(height: 24),
            _buildDaysSelector(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            // const SizedBox(height: 16),
            // _buildTestButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уведомления',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Регулярные напоминания',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() => _notificationsEnabled = value);
              await _saveNotificationSettings();
              if (value) {
                await _scheduleNotifications();
              } else {
                await _cancelAllNotifications();
              }
            },
            activeColor: primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Время напоминания',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectTime(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, color: primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime.format(context),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Дни недели',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedDays[index] = !_selectedDays[index]);
                  await _saveNotificationSettings();
                  await _scheduleNotifications();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedDays[index]
                        ? primaryBlue
                        : Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      days[index],
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedDays[index]
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await _saveNotificationSettings();
          await _scheduleNotifications();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _notificationsEnabled
                    ? 'Напоминания настроены'
                    : 'Напоминания отключены',
                style: GoogleFonts.manrope(),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Сохранить настройки',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Widget _buildTestButton() {
  //   return SizedBox(
  //     width: double.infinity,
  //     child: ElevatedButton(
  //       onPressed: _testNotification,
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: Colors.grey.shade100,
  //         padding: const EdgeInsets.symmetric(vertical: 16),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         elevation: 0,
  //       ),
  //       child: Text(
  //         'Тестовое уведомление',
  //         style: GoogleFonts.manrope(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //           color: primaryBlue,
  //         ),
  //       ),
  //     ),
  //   );
  // }
}