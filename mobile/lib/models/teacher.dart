class TeacherProfile {
  final String id;
  final String fullName;
  final String? badgeNumber;
  final String? department;
  final String? jobTitle;
  final String? phone;
  final String? photoUrl;
  final String role;

  TeacherProfile({
    required this.id,
    required this.fullName,
    this.badgeNumber,
    this.department,
    this.jobTitle,
    this.phone,
    this.photoUrl,
    required this.role,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) => TeacherProfile(
        id: json['id'],
        fullName: json['full_name'],
        badgeNumber: json['badge_number'],
        department: json['department'],
        jobTitle: json['job_title'],
        phone: json['phone'],
        photoUrl: json['photo_url'],
        role: json['role'],
      );
}
