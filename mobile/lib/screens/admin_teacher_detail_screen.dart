import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/admin.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// سجل حضور معلم واحد من لوحة الإدارة — مقابل شاشة (جدول الدوام حضوري) بالنظام
/// المكتبي عند فتح ملف معلم محدد.
class AdminTeacherDetailScreen extends StatefulWidget {
  final TeacherSummary teacher;
  const AdminTeacherDetailScreen({super.key, required this.teacher});

  @override
  State<AdminTeacherDetailScreen> createState() => _AdminTeacherDetailScreenState();
}

class _AdminTeacherDetailScreenState extends State<AdminTeacherDetailScreen> {
  final _api = ApiService();
  List<AttendanceStatusDay> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _api.fetchTeacherStatusHistory(widget.teacher.id, days: 30);
      setState(() => _history = history);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.teacher.fullName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (widget.teacher.department != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(widget.teacher.department!, style: const TextStyle(color: AppColors.textMuted)),
                        ),
                      const Text(
                        'سجل الحضور — آخر 30 يوم',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا يوجد سجل خلال هذه الفترة', style: TextStyle(color: AppColors.textMuted)),
                        )
                      else
                        ..._history.map((s) => _StatusRow(day: s)),
                    ],
                  ),
                ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final AttendanceStatusDay day;
  const _StatusRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = statusColors(day.status);
    final dateStr = intl.DateFormat('EEEE، d MMMM', 'ar').format(day.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 14))),
          if (day.status == 'late' && day.minutesLate != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('${day.minutesLate} د', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(statusLabel(day.status), style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
