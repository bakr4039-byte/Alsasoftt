/// نماذج بيانات خاصة بلوحة الإدارة/المشرفين — مقابل الشاشة الرئيسية وجدول الدوام
/// بالنظام المكتبي، لكن بتصميم جوال مبسّط (وليس نسخ حرفي للجداول الكثيفة).
class AdminSummary {
  final int total;
  final int present;
  final int absent;
  final int late;
  final int onLeave;
  final int notMarked;

  AdminSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.onLeave,
    required this.notMarked,
  });

  factory AdminSummary.fromJson(Map<String, dynamic> json) => AdminSummary(
        total: json['total'],
        present: json['present'],
        absent: json['absent'],
        late: json['late'],
        onLeave: json['on_leave'],
        notMarked: json['not_marked'],
      );
}

class TeacherSummary {
  final String id;
  final String fullName;
  final String? department;
  final String? todayStatus;

  TeacherSummary({
    required this.id,
    required this.fullName,
    this.department,
    this.todayStatus,
  });

  factory TeacherSummary.fromJson(Map<String, dynamic> json) => TeacherSummary(
        id: json['id'],
        fullName: json['full_name'],
        department: json['department'],
        todayStatus: json['today_status'],
      );
}
