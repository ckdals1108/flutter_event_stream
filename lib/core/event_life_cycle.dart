import 'package:flutter/widgets.dart';

class EventLifeCycle with WidgetsBindingObserver {
  final Function saveEvents;

  EventLifeCycle({required this.saveEvents}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 앱이 비활성 상태일 때
      saveEvents();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
