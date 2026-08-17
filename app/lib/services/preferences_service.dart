import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../configs/theme/downpeed_theme_tokens.dart';

enum DownloadCompletionAction { none, revealFile }

class PreferencesService extends GetxService {
  PreferencesService({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  static PreferencesService get to => Get.find<PreferencesService>();

  static const _prefix = 'downpeed';
  final GetStorage _storage;
  bool _initialized = false;

  final sidebarExpanded = true.obs;
  final sidebarWidth = DownpeedThemeTokens.sidebarWidth.obs;
  final completionNotificationsEnabled = true.obs;
  final downloadCompletionAction = DownloadCompletionAction.none.obs;
  final closeToTrayEnabled = true.obs;
  final startHiddenOnLogin = false.obs;

  Future<void> init() async {
    await _storage.initStorage;
    _initialized = true;
    sidebarExpanded.value =
        _storage.read<bool>('${_prefix}_sidebar_expanded') ?? true;
    final storedWidth = _storage.read<num>('${_prefix}_sidebar_width');
    sidebarWidth.value =
        (storedWidth?.toDouble() ?? DownpeedThemeTokens.sidebarWidth)
            .clamp(
              DownpeedThemeTokens.sidebarMinWidth,
              DownpeedThemeTokens.sidebarMaxWidth,
            )
            .toDouble();
    completionNotificationsEnabled.value =
        _storage.read<bool>('${_prefix}_completion_notifications') ?? true;
    downloadCompletionAction.value = switch (_storage.read<String>(
      '${_prefix}_download_completion_action',
    )) {
      'revealFile' => DownloadCompletionAction.revealFile,
      _ => DownloadCompletionAction.none,
    };
    closeToTrayEnabled.value =
        _storage.read<bool>('${_prefix}_close_to_tray') ?? true;
    startHiddenOnLogin.value =
        _storage.read<bool>('${_prefix}_start_hidden_on_login') ?? false;
  }

  int? get themeModeIndex =>
      _initialized ? _storage.read<int>('${_prefix}_theme_mode') : null;

  String? get localeCode =>
      _initialized ? _storage.read<String>('${_prefix}_locale') : null;

  Future<void> saveThemeModeIndex(int index) =>
      _write('${_prefix}_theme_mode', index);

  Future<void> saveLocaleCode(String code) => _write('${_prefix}_locale', code);

  Future<void> setSidebarExpanded(bool value) async {
    sidebarExpanded.value = value;
    await _write('${_prefix}_sidebar_expanded', value);
  }

  void updateSidebarWidth(double value) {
    sidebarWidth.value = value
        .clamp(
          DownpeedThemeTokens.sidebarMinWidth,
          DownpeedThemeTokens.sidebarMaxWidth,
        )
        .toDouble();
  }

  Future<void> persistSidebarWidth() =>
      _write('${_prefix}_sidebar_width', sidebarWidth.value);

  Future<void> resetSidebarWidth() async {
    sidebarWidth.value = DownpeedThemeTokens.sidebarWidth;
    await _write('${_prefix}_sidebar_width', sidebarWidth.value);
  }

  Future<void> setCompletionNotificationsEnabled(bool value) async {
    completionNotificationsEnabled.value = value;
    await _write('${_prefix}_completion_notifications', value);
  }

  Future<void> setDownloadCompletionAction(
    DownloadCompletionAction value,
  ) async {
    downloadCompletionAction.value = value;
    await _write('${_prefix}_download_completion_action', value.name);
  }

  Future<void> setCloseToTrayEnabled(bool value) async {
    closeToTrayEnabled.value = value;
    await _write('${_prefix}_close_to_tray', value);
  }

  Future<void> setStartHiddenOnLogin(bool value) async {
    startHiddenOnLogin.value = value;
    await _write('${_prefix}_start_hidden_on_login', value);
  }

  Future<void> _write(String key, Object value) async {
    if (_initialized) await _storage.write(key, value);
  }
}
