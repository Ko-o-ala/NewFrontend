import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 0)
class Message extends HiveObject {
  @HiveField(0)
  String sender;

  @HiveField(1)
  String text;

  Message({required this.sender, required this.text});
}
