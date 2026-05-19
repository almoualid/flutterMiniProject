import 'package:hive/hive.dart';

@HiveType(typeId: 20)
enum MessageRole {
  @HiveField(0)
  user,

  @HiveField(1)
  model,
}

@HiveType(typeId: 21)
class ChatMessage {
  @HiveField(0)
  final String content;

  @HiveField(1)
  final String apiContent;

  @HiveField(2)
  final MessageRole role;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final bool isLoading;

  const ChatMessage({
    required this.content,
    required this.role,
    required this.timestamp,
    String? apiContent,
    this.isLoading = false,
  }) : apiContent = apiContent ?? content;

  factory ChatMessage.fromUser(String text) => ChatMessage(
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.fromUserWithFile({
    required String displayText,
    required String apiText,
  }) =>
      ChatMessage(
        content: displayText,
        apiContent: apiText,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.fromModel(String text) => ChatMessage(
        content: text,
        role: MessageRole.model,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.loading() => ChatMessage(
        content: '',
        role: MessageRole.model,
        timestamp: DateTime.now(),
        isLoading: true,
      );
}

class MessageRoleAdapter extends TypeAdapter<MessageRole> {
  @override
  final int typeId = 20;

  @override
  MessageRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageRole.user;
      case 1:
        return MessageRole.model;
      default:
        return MessageRole.user;
    }
  }

  @override
  void write(BinaryWriter writer, MessageRole obj) {
    switch (obj) {
      case MessageRole.user:
        writer.writeByte(0);
        break;
      case MessageRole.model:
        writer.writeByte(1);
        break;
    }
  }
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 21;

  @override
  ChatMessage read(BinaryReader reader) {
    final fieldsCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldsCount; i++) reader.readByte(): reader.read(),
    };

    return ChatMessage(
      content: fields[0] as String? ?? '',
      apiContent: fields[1] as String?,
      role: fields[2] as MessageRole? ?? MessageRole.user,
      timestamp: fields[3] as DateTime? ?? DateTime.now(),
      isLoading: fields[4] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.apiContent)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.isLoading);
  }
}
