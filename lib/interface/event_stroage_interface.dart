import 'package:event_stream/model/event_model.dart';

abstract class EventStorageInterface {
  Future<void> init();
  Future<void> saveEvents(List<EventModel> events);
  Future<List<EventModel>> getEvents();
  Future<void> removeEvents(List<String> eventIds);
  Future<void> setUser({required String id, required String deviceId});
  Future<void> getUser();
  Future<void> removeUser();
}
