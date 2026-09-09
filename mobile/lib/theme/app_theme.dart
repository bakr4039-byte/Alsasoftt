import 'package:flutter/material.dart';

/// ألوان مستوحاة من ثيم "royalblue" المستخدم في النظام المكتبي الحالي،
/// حتى يشعر المعلم أن التطبيق امتداد لنفس النظام لا شيء منفصل عنه.
class AppColors {
  static const accent = Color(0xFF2456A6);
  static const accentDark = Color(0xFF17346B);
  static const accentSoft = Color(0xFFE7EEFA);
  static const good = Color(0xFF1C8A56);
  static const goodSoft = Color(0xFFE4F5EC);
  static const warn = Color(0xFFB8720C);
  static const warnSoft = Color(0xFFFBF0DD);
  static const bad = Color(0xFFB8402A);
  static const badSoft = Color(0xFFFBE7E1);
  static const bg = Color(0xFFF6F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE3ED);
  static const text = Color(0xFF16202E);
  static const textMuted = Color(0xFF5B6577);
}

ThemeData buildHaderTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Tajawal',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// يعيد لون وخلفية الحالة (حاضر/متأخر/غائب...) للاستخدام في الشارات (badges).
(Color, Color) statusColors(String status) {
  switch (status) {
    case 'present':
      return (AppColors.good, AppColors.goodSoft);
    case 'late':
      return (AppColors.warn, AppColors.warnSoft);
    case 'absent':
    case 'unexcused_leave':
    case 'violation':
      return (AppColors.bad, AppColors.badSoft);
    default:
      return (AppColors.textMuted, AppColors.accentSoft);
  }
}

String statusLabel(String status) {
  const labels = {
    'present': 'حاضر',
    'late': 'متأخر',
    'absent': 'غائب',
    'excused_leave': 'إجازة بعذر',
    'unexcused_leave': 'إجازة بدون عذر',
    'permission': 'استئذان',
    'violation': 'مخالفة',
    'commendation': 'شكر وتقدير',
  };
  return labels[status] ?? status;
}
