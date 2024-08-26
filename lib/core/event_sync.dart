import 'dart:convert';

import 'package:event_stream/model/event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EventSync {
  final String _serverUrl;
  final http.Client _client;

  EventSync(this._serverUrl, {http.Client? client})
      : _client = client ?? http.Client();

  Future<bool> sendEvents(List<EventModel> events) async {
    try {
      final response = await _client.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(events.map((e) => e.toJson()).toList()),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('이벤트 전송 중 오류 발생: $e');
      return false;
    }
  }
}
