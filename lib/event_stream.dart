library event_stream;

import 'dart:async';

import 'package:event_stream/core/event_life_cycle.dart';
import 'package:event_stream/core/event_stream_hive_storage.dart';
import 'package:event_stream/core/event_sync.dart';
import 'package:event_stream/interface/event_stroage_interface.dart';
import 'package:event_stream/model/event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

abstract class EventStreamInterface {
  void track({
    required String name,
    required Map<String, dynamic> properties,
  });
}

class EventStream implements EventStreamInterface {
  static EventStream? _instance;
  late final int _batchSize;
  late final String _serverUrl;
  late final EventStorageInterface _storage;
  late final EventSync _sync;
  late final EventLifeCycle _eventLifeCycle;

  factory EventStream({
    required String serverUrl,
    int batchSize = 10,
  }) {
    return _instance ??= EventStream._internal(serverUrl, batchSize);
  }

  EventStream._internal(String serverUrl, int batchSize) {
    _serverUrl = serverUrl;
    _batchSize = batchSize;
    _init();
  }

  final _eventController = StreamController<EventModel>();
  late final Stream<List<EventModel>> _batchStream;

  void _init() async {
    _storage = HiveEventStorage();
    _sync = EventSync(_serverUrl);
    _eventLifeCycle = EventLifeCycle(saveEvents: _saveEvents);

    // 스토리지 초기화
    await _storage.init();
    // 이벤트 로드
    await _loadEvents();

    // 이벤트 배치 처리 스트림 생성
    _batchStream =
        _eventController.stream.bufferCount(_batchSize).asyncMap((batch) async {
      await _processEventBatch(batch);
      return batch;
    });
  }

  @override
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
    _eventController.sink.add(event);
  }

  Future<void> _processEventBatch(List<EventModel> batch) async {
    try {
      final success = await _sync.sendEvents(batch);
      debugPrint('success: $success');
      if (success != false) {
        // 배치 처리 실패 시 이벤트를 스트림 맨 뒤로 보냄
        for (var event in batch) {
          _eventController.sink.add(event);
        }
      }
    } catch (e) {
      debugPrint('배치 처리 중 오류 발생: $e');
      // 예외 발생 시에도 이벤트를 스트림 맨 뒤로 보냄
      for (var event in batch) {
        _eventController.sink.add(event);
      }
    }
  }

  Future<void> _loadEvents() async {
    final events = await _storage.getEvents();
    for (var event in events) {
      _eventController.add(event);
    }
  }

  Future<void> _saveEvents() async {
    final events = await _batchStream.expand((batch) => batch).toList();
    await _storage.saveEvents(events);
  }

  void dispose() {
    _eventController.close();
    _eventLifeCycle.dispose();
  }
}
