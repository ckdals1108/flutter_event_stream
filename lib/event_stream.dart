library event_stream;

import 'dart:async';
import 'dart:convert';

import 'package:event_stream/model/event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class EventStream {
  static final EventStream _instance = EventStream._internal();

  factory EventStream({
    required String serverUrl,
    int batchSize = 30,
  }) {
    _instance._serverUrl = serverUrl;
    _instance._batchSize = batchSize;
    _instance._init();
    return _instance;
  }

  EventStream._internal();

  late final EventStorage _storage;
  late final EventSync _sync;
  late final int _batchSize;
  late final String _serverUrl;

  final _eventController = StreamController<EventModel>();
  late final Stream<List<EventModel>> _batchStream;

  void _init() async {
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('Hive 초기화 중 오류 발생: $e');
    }
    _storage = EventStorage();
    _sync = EventSync(_serverUrl);
    await _loadEvents();

    _batchStream =
        _eventController.stream.bufferCount(_batchSize).asyncMap((batch) async {
      await _processEventBatch(batch);
      return batch;
    });

    _batchStream.listen(
      (batch) {
        debugPrint('성공적으로 ${batch.length}개의 이벤트를 처리했습니다');
      },
      onError: (error) {
        debugPrint('이벤트 처리 중 오류 발생: $error');
      },
    );
  }

  void track({
    required String name,
    required Map<String, dynamic> properties,
  }) {
    final event = EventModel(
      id: const Uuid().v4(),
      name: name,
      properties: properties,
      createdAt: DateTime.now(),
    );
    _eventController.add(event);
  }

  Future<void> _loadEvents() async {
    final events = await _storage.getEvents();
    for (var event in events) {
      _eventController.add(event);
    }
  }

  Future<bool> _processEventBatch(List<EventModel> batch) async {
    try {
      final success = await _sync.sendEvents(batch);
      if (success) {
        return true;
      } else {
        // 배치 처리 실패 시 이벤트를 스트림 맨 뒤로 보냄
        for (var event in batch) {
          _eventController.add(event);
        }
        return false;
      }
    } catch (e) {
      debugPrint('배치 처리 중 오류 발생: $e');
      // 예외 발생 시에도 이벤트를 스트림 맨 뒤로 보냄
      for (var event in batch) {
        _eventController.add(event);
      }
      return false;
    }
  }

  void dispose() {
    _eventController.close();
  }
}

class EventStorage {
  static const String _boxName = 'events';

  Future<void> saveEvent(List<EventModel> events) async {
    final box = await Hive.openBox<EventModel>(_boxName);
    await box.addAll(events);
  }

  Future<List<EventModel>> getEvents() async {
    final box = await Hive.openBox<EventModel>(_boxName);
    return box.values.toList();
  }

  Future<void> removeEvents(List<String> ids) async {
    final box = await Hive.openBox<EventModel>(_boxName);
    await box.deleteAll(ids);
  }
}

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
