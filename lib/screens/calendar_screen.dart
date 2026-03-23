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

  // --- HÀM POPUP CHỈNH SỬA ---
  void _showEditPopup(BuildContext context, Reminder item) {
    final titleController = TextEditingController(text: item.title);
    final contentController = TextEditingController(text: item.content);

    // Tạo biến tạm để lưu thời gian đang sửa trong Popup
    DateTime tempSelectedDate = DateFormat('yyyy-MM-dd HH:mm').parse(item.time);
    String selectedPriority = item.priority;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Chỉnh sửa công việc"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Tiêu đề"),
                    ),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: "Nội dung"),
                    ),
                    const SizedBox(height: 15),

                    // --- PHẦN CHỌN LẠI THỜI GIAN ---
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month, color: Colors.orange),
                      title: Text(
                        DateFormat('HH:mm - dd/MM/yyyy').format(tempSelectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () async {
                        // Chọn ngày
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: tempSelectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );

                        if (pickedDate != null) {
                          // Chọn giờ
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(tempSelectedDate),
                          );

                          if (pickedTime != null) {
                            // Cập nhật biến tạm và refresh giao diện Popup
                            setPopupState(() {
                              tempSelectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: selectedPriority,
                      isExpanded: true,
                      items: ['High', 'Medium', 'Low'].map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (val) {
                        setPopupState(() => selectedPriority = val!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () async {
                    final updatedReminder = Reminder(
                      id: item.id,
                      title: titleController.text,
                      content: contentController.text,
                      // Lưu định dạng chuẩn yyyy-MM-dd HH:mm vào DB
                      time: DateFormat('yyyy-MM-dd HH:mm').format(tempSelectedDate),
                      priority: selectedPriority,
                      category: item.category,
                      isDone: item.isDone,
                    );

                    await _dbHelper.updateReminder(updatedReminder);

                    if (mounted) {
                      Navigator.pop(context);
                      loadAllEvents(); // Load lại để cập nhật dấu chấm trên lịch nếu đổi ngày
                    }
                  },
                  child: const Text("Lưu", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
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
              weekendTextStyle: const TextStyle(color: Colors.redAccent),
              todayDecoration: BoxDecoration(color: Colors.orange.withOpacity(0.3), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CÔNG VIỆC", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _selectedEvents.isEmpty
                        ? Center(child: Text("Không có việc nào", style: TextStyle(color: secondaryTextColor)))
                        : ListView.builder(
                      itemCount: _selectedEvents.length,
                      itemBuilder: (context, index) {
                        final item = _selectedEvents[index];
                        return Card(
                          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            // --- CLICK ĐỂ MỞ POPUP EDIT ---
                            onTap: () {
                              if (item.isDone == 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Công việc đã hoàn thành không thể sửa!")),
                                );
                              } else {
                                _showEditPopup(context, item);
                              }
                            },
                            leading: Checkbox(
                              value: item.isDone == 1,
                              activeColor: Colors.orange,
                              onChanged: (val) async {
                                await _dbHelper.updateStatus(item.id!, val! ? 1 : 0); // [cite: 17]
                                loadAllEvents();
                              },
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: textColor,
                                decoration: item.isDone == 1 ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              item.priority,
                              style: TextStyle(color: item.priority == 'High' ? Colors.red : Colors.orange), // [cite: 24]
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
          await Navigator.push(context, MaterialPageRoute(builder: (context) =>  AddReminderScreen()));
          loadAllEvents();
        },
      ),
    );
  }
}