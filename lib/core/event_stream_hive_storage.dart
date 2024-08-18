import 'package:event_stream/interface/event_stroage_interface.dart';
import 'package:event_stream/model/event_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveEventStorage implements EventStorageInterface {
  static const String _boxName = 'events';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
  }

  @override
  Future<void> saveEvents(List<EventModel> events) async {
    final box = await Hive.openBox<EventModel>(_boxName);
    await box.addAll(events);
  }

  @override
  Future<List<EventModel>> getEvents() async {
    final box = await Hive.openBox<EventModel>(_boxName);
    return box.values.toList();
  }

  @override
  Future<void> removeEvents(List<String> ids) async {
    final box = await Hive.openBox<EventModel>(_boxName);
    await box.deleteAll(ids);
  }
}
