import 'package:event_stream/model/event_model.dart';

abstract class EventStorageInterface {
  EventStorageInterface() {
    init();
  }
  Future<void> init();
  Future<void> saveEvents(List<EventModel> events);
  Future<List<EventModel>> getEvents();
  Future<void> removeEvents(List<String> eventIds);
}
