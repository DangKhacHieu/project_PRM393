import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  DateTime _selectedDate = DateTime.now(); // Lưu trữ tháng/năm đang xem

  // Hàm tính toán nhận xét năng suất
  Map<String, dynamic> _getFeedback(int completed, int overdue, int total) {
    if (total == 0) return {'text': 'Chưa có dữ liệu', 'color': Colors.grey};

    // Tính hiệu suất dựa trên tỉ lệ hoàn thành và trừ điểm trễ hạn
    double score = (completed / total) * 100;
    if (score >= 85) return {'text': 'Quá Năng Suất! ', 'color': Colors.green};
    if (score >= 65) return {'text': 'Làm tốt lắm! ', 'color': Colors.blue};
    if (overdue > completed) return {'text': 'Cần tập trung hơn, trễ nhiều quá! 📉', 'color': Colors.red};
    return {'text': 'Cố gắng hoàn thành nốt nhé! ', 'color': Colors.orange};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Phân tích năng suất"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // BỘ CHỌN THÁNG/NĂM
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1)),
                ),
                Text(
                  "Tháng ${_selectedDate.month} / ${_selectedDate.year}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1)),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              // Chú ý: Bạn cần cập nhật DBHelper thêm hàm getMonthlyStatistics(month, year)
              future: DBHelper().getMonthlyStatistics(_selectedDate.month, _selectedDate.year),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!['status'] == null) {
                  return const Center(child: Text("Không có dữ liệu cho tháng này"));
                }

                final status = snapshot.data!['status'];
                final categories = snapshot.data!['categories'] as List<Map<String, dynamic>>;

                int completed = status['completed'] ?? 0;
                int overdue = status['overdue'] ?? 0;
                int pending = status['pending'] ?? 0;
                int total = completed + overdue + pending;

                final feedback = _getFeedback(completed, overdue, total);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // CARD KẾT LUẬN NĂNG SUẤT (Giá trị UX mới) [cite: 37, 39]
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border(
                              left: BorderSide(color: feedback['color'], width: 5), // ĐÚNG: Nằm trong Border
                            ),
                          ),
                          child: Column(
                            children: [
                              Text("Đánh giá năng suất", style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 5),
                              Text(feedback['text'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: feedback['color'])),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // BIỂU ĐỒ TRÒN (Visualization) [cite: 33, 34, 36]
                      const Text("Trạng thái công việc", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 45,
                            sections: [
                              if (completed > 0) _section(completed.toDouble(), Colors.green, "Xong"),
                              if (overdue > 0) _section(overdue.toDouble(), Colors.red, "Trễ"),
                              if (pending > 0) _section(pending.toDouble(), Colors.blue, "Chờ"),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Divider(),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Thống kê theo Danh mục", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),

                      // DANH SÁCH CATEGORY (List View) [cite: 8]
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.folder, color: Colors.blueAccent),
                              title: Text(cat['category'] ?? "Chưa phân loại"),
                              trailing: Text("${cat['count']} việc", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(double value, Color color, String title) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: title,
      radius: 50,
      titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}