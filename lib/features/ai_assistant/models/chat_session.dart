// lib/features/ai_assistant/models/chat_session.dart

import 'package:hive/hive.dart';

import 'chat_message.dart';

@HiveType(typeId: 22)
class ChatSession {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<ChatMessage> messages;

  @HiveField(3)
  final DateTime createdAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 22;

  @override
  ChatSession read(BinaryReader reader) {
    final fieldsCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldsCount; i++) reader.readByte(): reader.read(),
    };

    final rawMessages = fields[2];
    final messages = rawMessages is List
        ? rawMessages.whereType<ChatMessage>().toList()
        : <ChatMessage>[];

    return ChatSession(
      id: fields[0] as String? ?? '',
      title: fields[1] as String? ?? 'Nouvelle discussion',
      messages: messages,
      createdAt: fields[3] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.messages)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}
