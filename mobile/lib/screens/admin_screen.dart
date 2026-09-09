import 'package:flutter/material.dart';

import '../models/admin.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'admin_teacher_detail_screen.dart';
import 'login_screen.dart';

/// لوحة المشرف/الإدارة — مقابل (الشاشة الرئيسية) بالنظام المكتبي: إحصائيات اليوم،
/// قائمة المعلمين، وتسجيل سريع لحالة كل معلم. بتصميم جوال مبسّط وليس نسخ حرفي
/// للوحة الكثيفة الأصلية.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _api = ApiService();

  AdminSummary? _summary;
  List<TeacherSummary> _teachers = [];
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
      final summary = await _api.fetchAdminSummary();
      final teachers = await _api.fetchAdminTeachers();
      setState(() {
        _summary = summary;
        _teachers = teachers;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _quickMark(TeacherSummary teacher) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => _QuickMarkSheet(teacherName: teacher.fullName),
    );
    if (status == null) return;
    try {
      await _api.markTeacherAttendance(teacher.id, status);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسجيل حالة ${teacher.fullName}: ${statusLabel(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_summary != null) _SummaryGrid(summary: _summary!),
                      const SizedBox(height: 22),
                      const Text(
                        'المعلمون اليوم',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 10),
                      if (_teachers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا يوجد معلمون مسجّلون بعد', style: TextStyle(color: AppColors.textMuted)),
                        )
                      else
                        ..._teachers.map((t) => _TeacherRow(
                              teacher: t,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => AdminTeacherDetailScreen(teacher: t)),
                              ),
                              onMark: () => _quickMark(t),
                            )),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final AdminSummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (_StatTile(label: 'إجمالي المعلمين', value: summary.total, color: AppColors.accent, bg: AppColors.accentSoft)),
      (_StatTile(label: 'حاضر', value: summary.present, color: AppColors.good, bg: AppColors.goodSoft)),
      (_StatTile(label: 'متأخر', value: summary.late, color: AppColors.warn, bg: AppColors.warnSoft)),
      (_StatTile(label: 'غائب', value: summary.absent, color: AppColors.bad, bg: AppColors.badSoft)),
      (_StatTile(label: 'إجازة/استئذان', value: summary.onLeave, color: AppColors.textMuted, bg: AppColors.accentSoft)),
      (_StatTile(label: 'لم يُسجَّل بعد', value: summary.notMarked, color: AppColors.textMuted, bg: AppColors.bg)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  const _StatTile({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  final TeacherSummary teacher;
  final VoidCallback onTap;
  final VoidCallback onMark;
  const _TeacherRow({required this.teacher, required this.onTap, required this.onMark});

  @override
  Widget build(BuildContext context) {
    final hasStatus = teacher.todayStatus != null;
    final (fg, bg) = hasStatus ? statusColors(teacher.todayStatus!) : (AppColors.textMuted, AppColors.bg);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.fullName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    if (teacher.department != null) ...[
                      const SizedBox(height: 2),
                      Text(teacher.department!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  hasStatus ? statusLabel(teacher.todayStatus!) : 'لم يُسجَّل',
                  style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: onMark,
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.accent),
                tooltip: 'تسجيل سريع',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMarkSheet extends StatelessWidget {
  final String teacherName;
  const _QuickMarkSheet({required this.teacherName});

  static const _options = [
    ('present', 'حاضر'),
    ('late', 'متأخر'),
    ('absent', 'غائب'),
    ('excused_leave', 'إجازة بعذر'),
    ('unexcused_leave', 'إجازة بدون عذر'),
    ('permission', 'استئذان'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تسجيل حالة: $teacherName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options
                  .map((o) => ActionChip(
                        label: Text(o.$2),
                        onPressed: () => Navigator.of(context).pop(o.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.bad, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
