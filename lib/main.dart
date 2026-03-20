import 'package:flutter/material.dart';
import 'package:project_cuoi_ki/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; //
import 'models/reminder.dart';
import 'services/db_helper.dart';
import 'screens/add_reminder_screen.dart';
import 'screens/trash_screen.dart';
import 'screens/pomodoro_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  // Kiểm tra trạng thái đăng nhập trước khi chạy App
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  bool isDarkMode = prefs.getBool('isDarkMode') ?? false; //

  runApp(ReminderApp(initialLoggedIn: isLoggedIn, initialDarkMode: isDarkMode));
}

class ReminderApp extends StatefulWidget {
  final bool initialLoggedIn;
  final bool initialDarkMode;

  const ReminderApp({
    super.key,
    required this.initialLoggedIn,
    required this.initialDarkMode
  });

  @override
  State<ReminderApp> createState() => _ReminderAppState();
}

class _ReminderAppState extends State<ReminderApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }


  void _toggleTheme(bool val) async {
    setState(() {
      _isDarkMode = val; // Chỉ cập nhật biến để Flutter vẽ lại màu
    });

    // Lưu vào máy chạy ngầm (Async)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', val);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reminder App',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),


      initialRoute: widget.initialLoggedIn ? '/home' : '/',

      routes: {
        // Route chính: Luôn khóa Light Mode cho Login
        '/': (context) => Theme(
          data: ThemeData(brightness: Brightness.light, useMaterial3: true, colorSchemeSeed: Colors.amber),
          child: const LoginScreen(),
        ),
        // Đăng ký cũng khóa Light Mode
        '/register': (context) => Theme(
          data: ThemeData(brightness: Brightness.light, useMaterial3: true, colorSchemeSeed: Colors.amber),
          child: const RegisterScreen(),
        ),
        //  Định nghĩa tên '/home'
        '/home': (context) => HomeScreen(
            isDarkMode: _isDarkMode,
            onThemeChanged: _toggleTheme
        ),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Reminder> _allReminders = [];
  List<Reminder> _filteredReminders = [];
  List<String> _categories = ['All'];

  final TextEditingController _searchController = TextEditingController();
  String _currentStatusFilter = 'All';
  String _selectedCategory = 'All';
  String _sortBy = 'Deadline';

  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _refreshData();
  }

  void _requestPermission() {
    NotificationService().flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _refreshData() async {
    final data = await DBHelper().getReminders();
    final dbCats = await DBHelper().getCategories();

    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    DateTime todayStart = DateTime(now.year, now.month, now.day);

    setState(() {
      _categories = ['All', ...dbCats];
      _allReminders = data.where((item) {
        DateTime taskDate = DateFormat("yyyy-MM-dd").parse(item.time.substring(0, 10));
        bool isToday = item.time.startsWith(todayStr);
        bool isOverdue = taskDate.isBefore(todayStart) && item.isDone == 0;
        return isToday || isOverdue;
      }).toList();
      _applyFilterAndSearch();
    });
  }

  void _refreshAllData() {
    _refreshData();
    _calendarKey.currentState?.loadAllEvents();
  }

  void _applyFilterAndSearch() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReminders = _allReminders.where((item) {
        bool matchesSearch = item.title.toLowerCase().contains(query);
        bool matchesStatus = true;
        if (_currentStatusFilter == 'Pending') matchesStatus = item.isDone == 0;
        else if (_currentStatusFilter == 'Completed') matchesStatus = item.isDone == 1;
        bool matchesCategory = (_selectedCategory == 'All' || item.category == _selectedCategory);
        return matchesSearch && matchesStatus && matchesCategory;
      }).toList();

      if (_sortBy == 'Deadline') {
        _filteredReminders.sort((a, b) => a.time.compareTo(b.time));
      } else {
        Map<String, int> priorityMap = {'High': 3, 'Medium': 2, 'Low': 1};
        _filteredReminders.sort((a, b) {
          int valA = priorityMap[a.priority] ?? 0;
          int valB = priorityMap[b.priority] ?? 0;
          return valB.compareTo(valA);
        });
      }
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Nhắc nhở"),
      actions: [
        // NÚT ĐĂNG XUẤT
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await NotificationService().cancelAllNotifications();
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', false);
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          onSelected: (val) {
            _sortBy = val;
            _applyFilterAndSearch();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Deadline', child: Text("Sắp xếp: Thời gian")),
            const PopupMenuItem(value: 'Priority', child: Text("Sắp xếp: Ưu tiên")),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const TrashScreen()));
            _refreshAllData();
          },
        ),
        IconButton(
          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () {
            // Bấm phát gọi hàm cha đổi màu luôn, không load lại trang
            widget.onThemeChanged(!widget.isDarkMode);
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Tìm kiếm lời nhắc...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _applyFilterAndSearch(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentStatusFilter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text("Tất cả trạng thái")),
                            DropdownMenuItem(value: 'Pending', child: Text("Sắp diễn ra")),
                            DropdownMenuItem(value: 'Completed', child: Text("Đã hoàn thành")),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _currentStatusFilter = val!;
                              _applyFilterAndSearch();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: _categories.map((String cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat == 'All' ? "Tất cả loại" : cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val!;
                              _applyFilterAndSearch();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderList() {
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);

    return _filteredReminders.isEmpty
        ? const Center(child: Text("Danh sách trống"))
        : ListView.builder(
      itemCount: _filteredReminders.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = _filteredReminders[index];
        DateTime taskDate = DateFormat("yyyy-MM-dd").parse(item.time.substring(0, 10));
        bool isOverdue = taskDate.isBefore(todayStart) && item.isDone == 0;

        return Card(
          color: isOverdue ? Colors.red.withOpacity(0.08) : _getPriorityColor(item.priority),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            onTap: () => _showUpdateDialog(item),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: item.isDone == 1 ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isOverdue)
                  const Text(
                    "QUÁ HẠN",
                    style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            subtitle: Text("${item.category} • ${item.time}"),
            leading: Checkbox(
              value: item.isDone == 1,
              activeColor: Colors.orange,
              onChanged: (bool? value) async {
                await DBHelper().updateStatus(item.id!, value! ? 1 : 0);
                _refreshAllData();
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () => _showDeleteConfirm(item),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(Reminder item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Chuyển '${item.title}' vào thùng rác?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              await DBHelper().moveToTrash(item.id!);
              await NotificationService().cancelNotification(item.id!);
              _refreshAllData();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(Reminder item) {
    final titleEditController = TextEditingController(text: item.title);
    final contentEditController = TextEditingController(text: item.content);
    String selectedPriority = item.priority;
    String selectedCategory = item.category;

    DateTime selectedDateTime;
    try {
      selectedDateTime = DateFormat("yyyy-MM-dd HH:mm").parse(item.time);
    } catch (e) {
      selectedDateTime = DateTime.now().add(const Duration(minutes: 5));
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Chỉnh sửa lời nhắc"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleEditController, decoration: const InputDecoration(labelText: "Tiêu đề")),
                    TextField(controller: contentEditController, decoration: const InputDecoration(labelText: "Nội dung")),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Giờ: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime)}"),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        DateTime? date = await showDatePicker(context: context, initialDate: selectedDateTime, firstDate: DateTime.now(), lastDate: DateTime(2030));
                        if (date != null) {
                          TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime));
                          if (time != null) {
                            setDialogState(() => selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                          }
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => selectedPriority = val!,
                      decoration: const InputDecoration(labelText: "Mức độ ưu tiên"),
                    ),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(selectedCategory) ? selectedCategory : _categories[1],
                      items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => selectedCategory = val!,
                      decoration: const InputDecoration(labelText: "Loại công việc"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () async {
                    Reminder updatedReminder = Reminder(
                      id: item.id,
                      title: titleEditController.text,
                      content: contentEditController.text,
                      time: DateFormat("yyyy-MM-dd HH:mm").format(selectedDateTime),
                      isDone: item.isDone,
                      priority: selectedPriority,
                      category: selectedCategory,
                      isDeleted: item.isDeleted,
                    );
                    await DBHelper().updateReminder(updatedReminder);
                    await NotificationService().scheduleNotification(
                      id: item.id!,
                      title: updatedReminder.title,
                      body: updatedReminder.content,
                      timeStr: DateFormat('HH:mm - dd/MM/yyyy').format(selectedDateTime),
                    );
                    _refreshAllData();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Lưu thay đổi"),
                ),
              ],
            );
          }
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.red.withOpacity(0.15);
      case 'Medium': return Colors.orange.withOpacity(0.15);
      case 'Low': return Colors.green.withOpacity(0.15);
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildReminderList(),
      CalendarScreen(key: _calendarKey),
      PomodoroScreen(),
    ];

    return Scaffold(
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) =>  AddReminderScreen()));
          _refreshAllData();
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) _refreshData();
          if (index == 1) _calendarKey.currentState?.loadAllEvents();
        },
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Nhắc nhở'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Pomodoro'),
        ],
      ),
    );
  }
}