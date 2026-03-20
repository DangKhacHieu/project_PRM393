import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  factory NotificationService() => _notificationService;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // --- ĐOẠN FIX LỖI EXACT ALARM ---
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 1. Tạo Channel (Bắt buộc)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'reminder_channel',
        'Nhắc nhở công việc',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);

      // 2. Xin quyền hiện thông báo cho Android 13+
      await androidPlugin.requestNotificationsPermission();
      try {
        // Sử dụng lệnh này để mở trang cài đặt "Báo thức & nhắc nhở"
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        print("Phiên bản plugin cũ không hỗ trợ requestExactAlarmsPermission: $e");
      }
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required String timeStr,
  }) async {
    try {
      // Giữ nguyên định dạng của ông cho đồng bộ với AddReminderScreen
      DateFormat inputFormat = DateFormat('HH:mm - dd/MM/yyyy');
      DateTime scheduledDate = inputFormat.parse(timeStr);

      if (scheduledDate.isBefore(DateTime.now())) {
        print(" Bỏ qua $title vì thời gian đã trôi qua.");
        return;
      }

      DateTime reminder15Min = scheduledDate.subtract(const Duration(minutes: 15));
      DateTime reminderNow = scheduledDate;

      final notificationDetails = const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Nhắc nhở công việc',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          // Thêm style này để hiển thị được nội dung dài khi nổ thông báo
          styleInformation: BigTextStyleInformation(''),
        ),
      );

      // --- ĐẶT LỊCH LẦN 1: NHẮC TRƯỚC 15 PHÚT ---
      if (reminder15Min.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          "⏰ Sắp đến giờ: $title",
          "Việc này sẽ bắt đầu sau 15 phút nữa!",
          tz.TZDateTime.from(reminder15Min, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Yêu cầu quyền Exact Alarm
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        print(" Đã đặt nhắc trước 15p lúc: $reminder15Min");
      }

      // --- ĐẶT LỊCH LẦN 2: NHẮC ĐÚNG GIỜ ---
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 10000,
        " BẮT ĐẦU: $title",
        "Đã đến giờ thực hiện công việc rồi m ơi!",
        tz.TZDateTime.from(reminderNow, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("✅ Đã đặt nhắc đúng giờ lúc: $reminderNow");

    } catch (e) {
      print(" Lỗi khi đặt lịch: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    await flutterLocalNotificationsPlugin.cancel(id + 10000);
    print("🗑 Đã hủy thông báo ID: $id và ${id + 10000}");
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print("🗑 Đã xóa sạch toàn bộ thông báo.");
  }
}