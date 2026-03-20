import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/db_helper.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Reminder> _trashedItems = [];

  void _loadTrash() async {
    final data = await DBHelper().getTrashedReminders();
    setState(() { _trashedItems = data; });
  }

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thùng rác"), backgroundColor: Colors.grey),
      body: _trashedItems.isEmpty
          ? const Center(child: Text("Thùng rác trống"))
          : ListView.builder(
        itemCount: _trashedItems.length,
        itemBuilder: (context, index) {
          final item = _trashedItems[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(item.title, style: const TextStyle(decoration: TextDecoration.lineThrough)),
              subtitle: Text(item.time),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút khôi phục
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.green),
                    onPressed: () async {
                      await DBHelper().restoreReminder(item.id!);
                      _loadTrash();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã khôi phục")));
                    },
                  ),
                  // Nút xóa vĩnh viễn
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () async {
                      await DBHelper().deletePermanently(item.id!);
                      _loadTrash();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}