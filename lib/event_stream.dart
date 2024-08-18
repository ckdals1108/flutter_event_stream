library event_stream;

import 'dart:collection';
import 'dart:convert';

import 'package:event_stream/model/event_model.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class EventStream with WidgetsBindingObserver {
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
  bool _isSlicingEvents = false;
  bool _isSyncingEvents = false;
  // 이벤트 임시 저장용 큐
  final Queue<EventModel> _eventQueue = Queue<EventModel>();
  // 이벤트 서버 통신용 큐
  final Queue<List<EventModel>> _streamQueue = Queue<List<EventModel>>();

  void _init() async {
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('Hive 초기화 중 오류 발생: $e');
    }
    _storage = EventStorage();
    _sync = EventSync(_serverUrl);
    _loadEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (_eventQueue.isEmpty) {
        _loadEvents();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      for (final events in _streamQueue) {
        await _storage.saveEvent(events);
      }
      await _storage.saveEvent(_eventQueue.toList());
      _streamQueue.clear();
      _eventQueue.clear();
    }
  }

  void track({
    required String name,
    required Map<String, dynamic> properties,
  }) {
    // 이벤트 생성
    final event = EventModel(
      id: const Uuid().v4(),
      name: name,
      properties: properties,
      createdAt: DateTime.now(),
    );
    // 이벤트 큐에 추가
    _eventQueue.addLast(event);
    // 이벤트 큐가 배치 사이즈 이상이면 이벤트 배치 생성
    if (!_isSlicingEvents && _eventQueue.length >= _batchSize) {
      // 이벤트 스트림 상태를 배치 생성 중으로 변경
      _isSlicingEvents = true;
      // 배치 생성
      final List<EventModel> batchEvents = [];
      for (int i = 0; i < _batchSize; i++) {
        final event = _eventQueue.removeFirst();
        batchEvents.add(event);
      }
      // 배치 이벤트 리스트를 스트림 큐에 추가
      _streamQueue.addLast(batchEvents);
      // 이벤트 스트림 상태를 배치 생성 완료로 변경
      _isSlicingEvents = false;
    }

    // 배치 이벤트 리스트 서버 동기화
    if (!_isSyncingEvents) {
      _syncEvents();
    }
  }

  Future<void> _loadEvents() async {
    final events = await _storage.getEvents();
    _eventQueue.addAll(events);
  }

  Future<void> _syncEvents() async {
    if (_streamQueue.isEmpty || _isSyncingEvents) return;

    _isSyncingEvents = true;

    final batch = _streamQueue.first;
    final success = await _sync.sendEvents(batch);

    if (success) {
      _streamQueue.removeFirst();
      debugPrint('성공적으로 ${batch.length}개의 이벤트를 동기화했습니다');
    } else {
      debugPrint('이벤트 동기화에 실패했습니다');
      _streamQueue.addLast(batch);
    }

    _isSyncingEvents = false;
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
