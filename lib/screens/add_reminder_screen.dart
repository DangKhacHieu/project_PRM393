import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class AddReminderScreen extends StatefulWidget {
  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedPriority = 'Medium';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  _loadCategories() async {
    final data = await DBHelper().getCategories();
    setState(() {
      _categories = data;
      if (_categories.isNotEmpty) _selectedCategory = _categories[0];
    });
  }

  _showAddCategoryDialog() {
    TextEditingController _catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Thêm loại mới"),
        content: TextField(controller: _catController, decoration: InputDecoration(hintText: "Nhập tên loại...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              if (_catController.text.isNotEmpty) {
                await DBHelper().insertCategory(_catController.text);
                await _loadCategories();
                setState(() => _selectedCategory = _catController.text);
                Navigator.pop(context);
              }
            },
            child: Text("Thêm"),
          )
        ],
      ),
    );
  }

  _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  // --- HÀM LƯU ĐÃ ĐƯỢC CẬP NHẬT ---
  _saveReminder() async {
    if (_titleController.text.isEmpty) return;

    // Định dạng để hiển thị thông báo
    final timeStrForNotification = DateFormat('HH:mm - dd/MM/yyyy').format(_selectedDate);

    // ĐỊNH DẠNG CHUẨN ĐỂ SQLITE LỌC ĐƯỢC
    final timeStrForDb = DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate);

    final newReminder = Reminder(
      title: _titleController.text,
      content: _contentController.text,
      time: timeStrForDb, // Lưu yyyy-MM-dd vào DB
      priority: _selectedPriority,
      category: _selectedCategory ?? "Chưa phân loại",
      isDone: 0,
    );

    await Future.delayed(Duration(milliseconds: 100));

    int idFromDb = await DBHelper().insert(newReminder);

    // định dạng  cho thông báo để người dùng dễ đọc
    await NotificationService().scheduleNotification(
      id: idFromDb,
      title: _titleController.text,
      body: _contentController.text,
      timeStr: timeStrForNotification,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tạo Lời Nhắc")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleController, decoration: InputDecoration(labelText: "Tiêu đề")),
            TextField(controller: _contentController, decoration: InputDecoration(labelText: "Nội dung")),
            SizedBox(height: 20),
            Text("Mức độ ưu tiên:", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedPriority,
              isExpanded: true,
              items: ['High', 'Medium', 'Low'].map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => _selectedPriority = val!),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Loại công việc:", style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.add_circle, color: Colors.green), onPressed: _showAddCategoryDialog)
              ],
            ),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories.map((String cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            SizedBox(height: 20),
            ListTile(
              title: Text("Thời gian: ${DateFormat('HH:mm - dd/MM/yyyy').format(_selectedDate)}"),
              trailing: Icon(Icons.access_time),
              onTap: _pickDateTime,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveReminder,
              child: Text("LƯU LỜI NHẮC"),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.amber),
            )
          ],
        ),
      ),
    );
  }
}