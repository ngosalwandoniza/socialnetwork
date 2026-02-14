import 'dart:async';
import 'package:flutter/foundation.dart';

/// A service that manages a single periodic timer for all background polling.
/// This reduces battery consumption and server load by grouping requests.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _timer;
  final List<AsyncCallback> _tasks = [];

  void register(AsyncCallback task) {
    if (!_tasks.contains(task)) {
      _tasks.add(task);
    }
  }

  void unregister(AsyncCallback task) {
    _tasks.remove(task);
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      for (final task in _tasks) {
        try {
          await task();
        } catch (e) {
          debugPrint('SyncService task error: $e');
        }
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
