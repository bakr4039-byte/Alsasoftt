import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/attendance.dart';
import '../models/teacher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();

  TeacherProfile? _profile;
  List<AttendanceStatusDay> _status = [];
  bool _loading = true;
  bool _checkingIn = false;
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
      final profile = await _api.fetchMe();
      final status = await _api.fetchAttendanceStatus(days: 14);
      setState(() {
        _profile = profile;
        _status = status;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doCheckIn(String type) async {
    setState(() => _checkingIn = true);
    try {
      // ملاحظة: في الإصدار الكامل يُستخدم حزمة geolocator لجلب الموقع الفعلي
      // وقد يُطلب أيضًا التحقق أن المعلم داخل نطاق المدرسة (Geofencing).
      await _api.checkIn(checkType: type, latitude: 24.7136, longitude: 46.6753);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'in' ? 'تم تسجيل الحضور بنجاح' : 'تم تسجيل الانصراف بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حاضر'),
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
                      _ProfileCard(profile: _profile!),
                      const SizedBox(height: 18),
                      _CheckInCard(loading: _checkingIn, onCheckIn: () => _doCheckIn('in'), onCheckOut: () => _doCheckIn('out')),
                      const SizedBox(height: 22),
                      const Text(
                        'سجل الحضور — آخر 14 يوم',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 10),
                      if (_status.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا يوجد سجل خلال هذه الفترة', style: TextStyle(color: AppColors.textMuted)),
                        )
                      else
                        ..._status.map((s) => _StatusRow(day: s)),
                    ],
                  ),
                ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final TeacherProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accentSoft,
              child: Text(
                profile.fullName.isNotEmpty ? profile.fullName.substring(0, 1) : '؟',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [profile.jobTitle, profile.department].where((e) => e != null).join(' · '),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  const _CheckInCard({required this.loading, required this.onCheckIn, required this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تسجيل الحضور من الجوال', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            const SizedBox(height: 4),
            const Text('يتم تسجيل موقعك عند الضغط، للتأكد من وجودك بالمدرسة.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onCheckIn,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('تسجيل حضور'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onCheckOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('تسجيل انصراف'),
                  ),
                ),
              ],
            ),
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
          Expanded(
            child: Text(dateStr, style: const TextStyle(fontSize: 14)),
          ),
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
