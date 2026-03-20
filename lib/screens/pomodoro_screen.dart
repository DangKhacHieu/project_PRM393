import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Đảm bảo đường dẫn này chính xác với project của bạn
import 'package:project_cuoi_ki/services/notification_service.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int maxSeconds = 25 * 60; // Mặc định 25 phút
  int seconds = 25 * 60;
  Timer? timer;
  bool isRunning = false;

  final int notificationId = 999;

  // --- LOGIC CẬP NHẬT THỜI GIAN ---
  void _updateTimerDuration(int mins) {
    stopTimer();
    setState(() {
      maxSeconds = mins * 60;
      seconds = maxSeconds;
    });
  }

  // --- HIỂN THỊ PICKER DẠNG CUỘN (CHỈ KHI CHỌN TÙY CHỈNH) ---
  void _showScrollPicker() {
    int selectedMins = maxSeconds ~/ 60;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Cuộn để chọn (Tối đa 180 phút)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedMins - 1),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) => selectedMins = index + 1,
                  children: List.generate(180, (i) => Center(child: Text('${i + 1} phút'))),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateTimerDuration(selectedMins);
                  Navigator.pop(context); // Đóng Picker
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("XÁC NHẬN", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- POPUP CHÍNH: CÁC MỤC CỐ ĐỊNH + NÚT TÙY CHỈNH ---
  void _showMainOptions() {
    if (isRunning) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Chọn thời gian tập trung",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Các mốc cố định: 15, 25, 45, 60
              Wrap(
                spacing: 10,
                children: [15, 25, 45, 60].map((min) {
                  return ActionChip(
                    label: Text("$min phút"),
                    onPressed: () {
                      _updateTimerDuration(min);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 30),
              // Nút Tùy chỉnh -> Mở vòng quay cuộn
              ListTile(
                leading: const Icon(Icons.tune, color: Colors.orange),
                title: const Text("Tùy chỉnh thời gian khác..."),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context); // Đóng menu chính
                  _showScrollPicker();    // Mở vòng quay cuộn
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- CÁC HÀM CƠ BẢN (START, STOP, RESET, NOTI) ---
  void _updateNotification() {
    String timeStr = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    NotificationService().flutterLocalNotificationsPlugin.show(
        notificationId, "Pomodoro đang chạy", "Còn lại: $timeStr",
        const NotificationDetails(android: AndroidNotificationDetails('pomodoro_channel', 'Pomodoro',
            importance: Importance.low, priority: Priority.low, ongoing: true, onlyAlertOnce: true, showWhen: false))
    );
  }

  void startTimer() {
    if (timer != null) timer!.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds > 0) {
        setState(() => seconds--);
        if (seconds % 5 == 0) _updateNotification();
      } else {
        stopTimer();
        // Bắn báo thức [cite: 15, 16]
      }
    });
    setState(() => isRunning = true);
    _updateNotification();
  }

  void stopTimer() {
    timer?.cancel();
    NotificationService().flutterLocalNotificationsPlugin.cancel(notificationId);
    setState(() => isRunning = false);
  }

  void resetTimer() {
    stopTimer();
    setState(() => seconds = maxSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("TẬP TRUNG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 2)),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _showMainOptions, // Nhấp vào số để hiện tùy chọn
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260, height: 260,
                    child: CircularProgressIndicator(
                      value: seconds / maxSeconds,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(isRunning ? Colors.orange : Colors.grey),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold)),
                      if (!isRunning) const Text("Chạm để chỉnh", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning ? stopTimer : startTimer,
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(isRunning ? "Tạm dừng" : "Bắt đầu"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? Colors.red.shade400 : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(width: 25),
                IconButton(onPressed: resetTimer, icon: const Icon(Icons.refresh), iconSize: 35, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}