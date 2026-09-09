import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin.dart';
import '../models/attendance.dart';
import '../models/teacher.dart';

/// عنوان الـ API. عند التطوير المحلي على المحاكي:
///  - محاكي أندرويد: 10.0.2.2 بدل localhost
///  - جهاز آيفون حقيقي على نفس الشبكة: عنوان IP الفعلي لجهاز السيرفر
const String kApiBaseUrl = String.fromEnvironment(
  'HADER_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8811',
);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const _tokenKey = 'hader_access_token';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async => (await _getToken()) != null;

  Map<String, String> _jsonHeaders() => {'Content-Type': 'application/json'};

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw ApiException('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    await _saveToken(data['access_token']);
  }

  Future<TeacherProfile> fetchMe() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/me'), headers: await _authHeaders());
    if (res.statusCode != 200) throw ApiException('تعذّر جلب بيانات الحساب');
    return TeacherProfile.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<List<AttendanceStatusDay>> fetchAttendanceStatus({int days = 30}) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/me/attendance/status?days=$days'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw ApiException('تعذّر جلب سجل الحضور');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return list.map((e) => AttendanceStatusDay.fromJson(e)).toList();
  }

  Future<List<AttendanceEvent>> fetchAttendanceEvents({int days = 30}) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/me/attendance/events?days=$days'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw ApiException('تعذّر جلب سجل البصمات');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return list.map((e) => AttendanceEvent.fromJson(e)).toList();
  }

  Future<AttendanceEvent> checkIn({
    required String checkType, // in | out
    double? latitude,
    double? longitude,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/attendance/checkin'),
      headers: {..._jsonHeaders(), ...await _authHeaders()},
      body: jsonEncode({
        'check_type': checkType,
        'source': 'mobile_gps',
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
    if (res.statusCode != 200) throw ApiException('تعذّر تسجيل الحضور، حاول مرة أخرى');
    return AttendanceEvent.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ---- لوحة الإدارة/المشرفين ----

  Future<AdminSummary> fetchAdminSummary() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/admin/summary'), headers: await _authHeaders());
    if (res.statusCode != 200) throw ApiException('تعذّر جلب إحصائيات اليوم');
    return AdminSummary.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<List<TeacherSummary>> fetchAdminTeachers() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/admin/teachers'), headers: await _authHeaders());
    if (res.statusCode != 200) throw ApiException('تعذّر جلب قائمة المعلمين');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return list.map((e) => TeacherSummary.fromJson(e)).toList();
  }

  Future<List<AttendanceStatusDay>> fetchTeacherStatusHistory(String teacherId, {int days = 30}) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/admin/teachers/$teacherId/status?days=$days'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw ApiException('تعذّر جلب سجل المعلم');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return list.map((e) => AttendanceStatusDay.fromJson(e)).toList();
  }

  Future<void> markTeacherAttendance(String teacherId, String status, {int? minutesLate}) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/admin/teachers/$teacherId/mark'),
      headers: {..._jsonHeaders(), ...await _authHeaders()},
      body: jsonEncode({'status': status, if (minutesLate != null) 'minutes_late': minutesLate}),
    );
    if (res.statusCode != 200) throw ApiException('تعذّر تسجيل الحالة، حاول مرة أخرى');
  }
}
