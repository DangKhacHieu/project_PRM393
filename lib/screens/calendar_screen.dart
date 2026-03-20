import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';
import '../models/reminder.dart';
import '../screens/add_reminder_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final DBHelper _dbHelper = DBHelper();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Reminder> _selectedEvents = [];
  Map<String, List<Reminder>> _allEvents = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    loadAllEvents();
  }

  // Load lại toàn bộ data để đồng bộ dấu chấm và danh sách
  void loadAllEvents() async {
    final events = await _dbHelper.getAllEventsForCalendar();
    if (mounted) {
      setState(() {
        _allEvents = events;
      });
      _updateSelectedEvents(_selectedDay);
    }
  }

  void _updateSelectedEvents(DateTime day) async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(day);
    final tasks = await _dbHelper.getRemindersByDate(formattedDate);
    if (mounted) {
      setState(() {
        _selectedEvents = tasks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy màu sắc từ Theme hệ thống để đồng bộ
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      // Không để Colors.black cố định, để nó tự theo Theme
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Tháng ${DateFormat('M').format(_focusedDay)}",
          style: TextStyle(color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              String dateKey = DateFormat('yyyy-MM-dd').format(day);
              return _allEvents[dateKey] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _updateSelectedEvents(selectedDay);
            },

            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: textColor),
              weekendTextStyle: TextStyle(color: Colors.redAccent),
              outsideTextStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.5)),
              todayDecoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
              rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
              titleTextStyle: TextStyle(color: textColor, fontSize: 18),
            ),
          ),
          const SizedBox(height: 20),
          // DANH SÁCH CHI TIẾT
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Tự động đổi màu nền bảng danh sách theo Dark/Light
                color: isDarkMode ? Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CÔNG VIỆC",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _selectedEvents.isEmpty
                        ? Center(child: Text("Không có việc nào", style: TextStyle(color: secondaryTextColor)))
                        : ListView.builder(
                      itemCount: _selectedEvents.length,
                      itemBuilder: (context, index) {
                        final item = _selectedEvents[index];
                        return Card(
                          color: isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: Checkbox(
                              value: item.isDone == 1,
                              activeColor: Colors.orange,
                              onChanged: (val) async {
                                // ĐỒNG BỘ TRẠNG THÁI VÀO DATABASE
                                await _dbHelper.updateStatus(item.id!, val! ? 1 : 0);
                                // Load lại cả 2 để đồng bộ icon trên lịch và list bên dưới
                                loadAllEvents();
                              },
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: textColor,
                                decoration: item.isDone == 1 ? TextDecoration.lineThrough : null, // Gạch ngang nếu xong
                              ),
                            ),
                            subtitle: Text(
                              item.priority,
                              style: TextStyle(
                                color: item.priority == 'High' ? Colors.red : Colors.orange,
                              ), // [cite: 24]
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          // 1. Chuyển sang trang thêm công việc
          await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddReminderScreen())
          );
          // 2. Sau khi người dùng nhấn "Lưu" và quay lại,
          // hàm loadAllEvents() sẽ chạy để cập nhật dấu chấm trên lịch ngay lập tức
          loadAllEvents();
        },
      ),
    );
  }
}