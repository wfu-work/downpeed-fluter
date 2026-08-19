import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app/pages/network/network_controller.dart';
import '../app/pages/overview/overview_controller.dart';
import '../app/pages/settings/settings_controller.dart';
import '../app/pages/task_detail/task_detail_controller.dart';
import '../app/pages/task_list/task_list_controller.dart';
import '../app/routes/app_pages.dart';
import 'download_dialog_service.dart';

typedef AppRouteNavigator = Future<void> Function(String route);
typedef AppDownloadDialogOpener = Future<void> Function(String initialUrl);
typedef AppVoidCommand = Future<void> Function();
typedef AppRouteRefresher = Future<void> Function(String route);

class AppCommandService extends GetxService {
  AppCommandService({
    AppRouteNavigator? navigateTo,
    AppDownloadDialogOpener? openDownloadDialog,
    AppVoidCommand? showWindow,
    AppVoidCommand? focusTaskSearch,
    AppRouteRefresher? refreshRoute,
  }) : _navigateToOverride = navigateTo,
       _openDownloadDialogOverride = openDownloadDialog,
       _showWindowOverride = showWindow,
       _focusTaskSearchOverride = focusTaskSearch,
       _refreshRouteOverride = refreshRoute;

  static AppCommandService get to => Get.find<AppCommandService>();

  final AppRouteNavigator? _navigateToOverride;
  final AppDownloadDialogOpener? _openDownloadDialogOverride;
  final AppVoidCommand? _showWindowOverride;
  final AppVoidCommand? _focusTaskSearchOverride;
  final AppRouteRefresher? _refreshRouteOverride;
  final Queue<_QueuedAppCommand> _pending = Queue<_QueuedAppCommand>();
  final errorMessage = RxnString();

  bool _navigationReady = false;
  bool _draining = false;

  Future<void> markNavigationReady() async {
    _navigationReady = true;
    await _drain();
  }

  Future<void> openNewDownload({String initialUrl = ''}) {
    if (_navigationReady && Get.isDialogOpen == true) {
      return Future<void>.value();
    }
    return _enqueue(() => _openNewDownload(initialUrl));
  }

  Future<void> focusTaskSearch() {
    if (_navigationReady && Get.isDialogOpen == true) {
      return Future<void>.value();
    }
    return _enqueue(_focusTaskSearch);
  }

  Future<void> openSettings() {
    if (_navigationReady && Get.isDialogOpen == true) {
      return Future<void>.value();
    }
    return _enqueue(() => _navigateTo(Routes.settings));
  }

  Future<void> refreshCurrent() {
    if (_navigationReady && Get.isDialogOpen == true) {
      return Future<void>.value();
    }
    return _enqueue(() {
      final route = Get.currentRoute.split('?').first;
      return (_refreshRouteOverride ?? _refreshCurrentRoute)(route);
    });
  }

  Future<void> openExternalDownload({required String initialUrl}) =>
      _enqueue(() => _openExternalDownload(initialUrl));

  Future<void> _openExternalDownload(String initialUrl) async {
    final showWindow = _showWindowOverride;
    if (showWindow != null) {
      await showWindow();
    }
    await _openNewDownload(initialUrl);
  }

  Future<void> _openNewDownload(String initialUrl) async {
    await _navigateTo(Routes.tasks);
    final openDialog = _openDownloadDialogOverride;
    if (openDialog != null) {
      await openDialog(initialUrl);
    } else {
      await DownloadDialogService.to.open(initialUrl: initialUrl);
    }
  }

  Future<void> _focusTaskSearch() async {
    await _navigateTo(Routes.tasks);
    final focus = _focusTaskSearchOverride;
    if (focus != null) {
      await focus();
    } else if (Get.isRegistered<TaskListController>()) {
      TaskListController.to.focusSearch();
    }
  }

  Future<void> _navigateTo(String route) async {
    final navigator = _navigateToOverride;
    if (navigator != null) {
      await navigator(route);
      return;
    }
    if (Get.currentRoute.split('?').first == route) return;
    Get.offAllNamed<void>(route);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _refreshCurrentRoute(String route) async {
    if (route == Routes.overview && Get.isRegistered<OverviewController>()) {
      await Get.find<OverviewController>().refresh();
      return;
    }
    if (route == Routes.tasks && Get.isRegistered<TaskListController>()) {
      await TaskListController.to.retryTasks();
      return;
    }
    if (route == Routes.network && Get.isRegistered<NetworkController>()) {
      await Get.find<NetworkController>().refresh();
      return;
    }
    if (route == Routes.settings && Get.isRegistered<SettingsController>()) {
      await Get.find<SettingsController>().refreshCurrent();
      return;
    }
    if (route.startsWith('${Routes.tasks}/') &&
        Get.isRegistered<TaskDetailController>()) {
      await Get.find<TaskDetailController>().refresh();
    }
  }

  Future<void> _enqueue(Future<void> Function() command) {
    final completer = Completer<void>();
    _pending.add(_QueuedAppCommand(command, completer));
    if (_navigationReady) unawaited(_drain());
    return completer.future;
  }

  Future<void> _drain() async {
    if (_draining || !_navigationReady) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final pending = _pending.removeFirst();
        try {
          errorMessage.value = null;
          await pending.run();
        } on Object {
          errorMessage.value =
              'The application command could not be completed.';
        } finally {
          if (!pending.completer.isCompleted) pending.completer.complete();
        }
      }
    } finally {
      _draining = false;
    }
  }
}

class _QueuedAppCommand {
  const _QueuedAppCommand(this.run, this.completer);

  final Future<void> Function() run;
  final Completer<void> completer;
}
