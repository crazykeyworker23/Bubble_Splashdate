class UserProfile {
  String username;
  String fullName;
  String? googleSub;
  String? avatarUrl;
  String? age;
  String? gender;
  String? description;
  String? address;
  String? occupation;
  String? educationLevel;
  double? longitude;
  double? latitude;
  String fcmToken;

  UserProfile({
    required this.username,
    required this.fullName,
    this.googleSub,
    this.avatarUrl,
    this.age,
    this.gender,
    this.description,
    this.address,
    this.occupation,
    this.educationLevel,
    this.longitude,
    this.latitude,
    required this.fcmToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, {required String fcmToken}) {
    return UserProfile(
      username: json['use_txt_username'] ?? '',
      fullName: json['use_txt_fullname'] ?? '',
      googleSub: json['use_txt_googlesub'],
      avatarUrl: json['use_txt_avatar'],
      age: json['use_txt_age']?.toString(),
      gender: json['use_txt_gender'],
      description: json['use_txt_description'],
      address: json['use_txt_address'],
      occupation: json['use_txt_occupation'],
      educationLevel: json['use_txt_educationlevel'],
      longitude: (json['use_double_longitude'] is num)
          ? (json['use_double_longitude'] as num).toDouble()
          : null,
      latitude: (json['use_double_latitude'] is num)
          ? (json['use_double_latitude'] as num).toDouble()
          : null,
      fcmToken: fcmToken,
    );
  }
}
