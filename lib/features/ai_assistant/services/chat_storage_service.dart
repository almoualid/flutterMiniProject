// lib/features/ai_assistant/services/chat_storage_service.dart

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';

class ChatStorageService {
  static const String _boxName = 'ai_chat_sessions';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(MessageRoleAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(ChatSessionAdapter());
    }

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<ChatSession>(_boxName);
    }

    _initialized = true;
  }

  static Future<Box<ChatSession>> _box() async {
    await init();
    return Hive.box<ChatSession>(_boxName);
  }

  static Future<void> saveSession(ChatSession session) async {
    final box = await _box();
    await box.put(session.id, session);
  }

  static Future<List<ChatSession>> loadAllSessions() async {
    final box = await _box();
    final sessions = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  static Future<void> deleteSession(String id) async {
    final box = await _box();
    await box.delete(id);
  }
}
