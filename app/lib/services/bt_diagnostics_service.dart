import 'dart:async';

import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../domains/bt_diagnostics.dart';

class BTDiagnosticsService extends GetxService {
  BTDiagnosticsService({
    required this.client,
    this.refreshInterval = const Duration(seconds: 2),
  });

  final EngineClient client;
  final Duration refreshInterval;
  final diagnostics = <String, BTDiagnostics>{}.obs;
  final loadingTaskIds = <String>{}.obs;
  final errors = <String, String>{}.obs;
  final _expandedTaskIds = <String>{};
  Timer? _timer;

  BTDiagnostics? forTask(String taskId) => diagnostics[taskId];

  bool isLoading(String taskId) => loadingTaskIds.contains(taskId);

  String? errorFor(String taskId) => errors[taskId];

  bool isExpanded(String taskId) => _expandedTaskIds.contains(taskId);

  Future<void> setExpanded(String taskId, bool expanded) async {
    if (taskId.isEmpty) return;
    if (expanded) {
      _expandedTaskIds.add(taskId);
      _ensureTimer();
      await refresh(taskId);
    } else {
      _expandedTaskIds.remove(taskId);
      if (_expandedTaskIds.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  Future<void> refresh(String taskId) async {
    if (loadingTaskIds.contains(taskId)) return;
    loadingTaskIds.add(taskId);
    errors.remove(taskId);
    try {
      diagnostics[taskId] = await client.fetchBTDiagnostics(taskId);
    } on EngineClientException catch (error) {
      errors[taskId] = error.message;
    } on Object {
      errors[taskId] = 'Could not load BitTorrent connection diagnostics.';
    } finally {
      loadingTaskIds.remove(taskId);
    }
  }

  void remove(String taskId) {
    _expandedTaskIds.remove(taskId);
    diagnostics.remove(taskId);
    errors.remove(taskId);
    loadingTaskIds.remove(taskId);
    if (_expandedTaskIds.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(refreshInterval, (_) {
      for (final taskId in _expandedTaskIds.toList(growable: false)) {
        unawaited(refresh(taskId));
      }
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
