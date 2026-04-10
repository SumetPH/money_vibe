import 'package:flutter/material.dart';

class Message {
  final String role; // 'user' หรือ 'assistant'
  final String content;

  Message({required this.role, required this.content});
}

class LlmProvider extends ChangeNotifier {
  final List<Message> _messages = [];

  List<Message> get messages => _messages;

  void limitMessages(int limit) {
    if (_messages.length > limit) {
      _messages.removeRange(0, _messages.length - limit);
      notifyListeners();
    }
  }

  void addMessage({required String role, required String content}) {
    _messages.add(Message(role: role, content: content));
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
