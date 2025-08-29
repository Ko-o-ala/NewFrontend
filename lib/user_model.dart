// lib/user_model.dart

class UserModel {
  final String name;
  final String birthdate;
  final int gender;
  final String id;

  UserModel({
    required this.name,
    required this.birthdate,
    required this.gender,
    required this.id,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      birthdate: json['birthdate'] ?? '',
      gender: json['gender'] ?? 0,
      id: json['id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'birthdate': birthdate, 'gender': gender, 'id': id};
  }
}
