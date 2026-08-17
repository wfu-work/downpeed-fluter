import 'package:get/get.dart';

import '../configs/localization/l10n_keys.dart';
import '../data/clients/engine_client.dart';
import '../domains/engine_settings.dart';

class EngineSettingsService extends GetxService {
  EngineSettingsService({required this.client});

  static EngineSettingsService get to => Get.find<EngineSettingsService>();

  final EngineClient client;
  final settings = Rxn<EngineSettings>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isSavingDefaultDownloadDirectory = false.obs;
  final errorMessage = RxnString();
  final fileConflictErrorMessage = RxnString();
  final schedulerErrorMessage = RxnString();
  final btPolicyErrorMessage = RxnString();

  String? get defaultDownloadDirectory =>
      settings.value?.defaultDownloadDirectory;

  SchedulerSettings? get scheduler => settings.value?.scheduler;

  FileConflictPolicy? get fileConflictPolicy =>
      settings.value?.fileConflictPolicy;

  BTPolicySettings? get bitTorrent => settings.value?.bitTorrent;

  Future<EngineSettings?> load({bool force = false}) async {
    if (isLoading.value || (!force && settings.value != null)) {
      return settings.value;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final value = await client.fetchSettings();
      settings.value = value;
      return value;
    } on EngineClientException catch (error) {
      errorMessage.value = _messageFor(error);
      return null;
    } on Object {
      errorMessage.value = L10nKeys.settingsDownloadDirectoryLoadError.tr;
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateDefaultDownloadDirectory(String directory) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    isSavingDefaultDownloadDirectory.value = true;
    errorMessage.value = null;
    try {
      final current = settings.value;
      if (current == null) return false;
      settings.value = await client.updateSettings(
        defaultDownloadDirectory: directory,
        fileConflictPolicy: current.fileConflictPolicy,
        scheduler: current.scheduler,
        bitTorrent: current.bitTorrent,
      );
      return true;
    } on EngineClientException catch (error) {
      errorMessage.value = _messageFor(error);
      return false;
    } on Object {
      errorMessage.value = L10nKeys.settingsDownloadDirectorySaveError.tr;
      return false;
    } finally {
      isSavingDefaultDownloadDirectory.value = false;
      isSaving.value = false;
    }
  }

  Future<bool> updateFileConflictPolicy(FileConflictPolicy policy) async {
    if (isSaving.value) return false;
    final current = settings.value;
    if (current == null) return false;
    isSaving.value = true;
    fileConflictErrorMessage.value = null;
    try {
      settings.value = await client.updateSettings(
        defaultDownloadDirectory: current.defaultDownloadDirectory,
        fileConflictPolicy: policy,
        scheduler: current.scheduler,
        bitTorrent: current.bitTorrent,
      );
      return true;
    } on EngineClientException catch (error) {
      fileConflictErrorMessage.value = switch (error.code) {
        'invalid_file_conflict_policy' =>
          L10nKeys.settingsFileConflictPolicyInvalid.tr,
        'engine_unreachable' => L10nKeys.settingsFileConflictPolicyOffline.tr,
        _ => L10nKeys.settingsFileConflictPolicySaveError.tr,
      };
      return false;
    } on Object {
      fileConflictErrorMessage.value =
          L10nKeys.settingsFileConflictPolicySaveError.tr;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateSchedulerSettings(SchedulerSettings scheduler) async {
    if (isSaving.value) return false;
    final current = settings.value;
    if (current == null) return false;
    isSaving.value = true;
    schedulerErrorMessage.value = null;
    try {
      settings.value = await client.updateSettings(
        defaultDownloadDirectory: current.defaultDownloadDirectory,
        fileConflictPolicy: current.fileConflictPolicy,
        scheduler: scheduler,
        bitTorrent: current.bitTorrent,
      );
      return true;
    } on EngineClientException catch (error) {
      schedulerErrorMessage.value = switch (error.code) {
        'invalid_scheduler_settings' => L10nKeys.settingsSchedulerInvalid.tr,
        'engine_unreachable' => L10nKeys.settingsSchedulerOffline.tr,
        _ => L10nKeys.settingsSchedulerSaveError.tr,
      };
      return false;
    } on Object {
      schedulerErrorMessage.value = L10nKeys.settingsSchedulerSaveError.tr;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateBTPeerConnections(int maxPeerConnections) async {
    if (isSaving.value) return false;
    final current = settings.value;
    if (current == null) return false;
    isSaving.value = true;
    btPolicyErrorMessage.value = null;
    try {
      settings.value = await client.updateSettings(
        defaultDownloadDirectory: current.defaultDownloadDirectory,
        fileConflictPolicy: current.fileConflictPolicy,
        scheduler: current.scheduler,
        bitTorrent: current.bitTorrent.copyWith(
          maxPeerConnections: maxPeerConnections,
        ),
      );
      return true;
    } on EngineClientException catch (error) {
      btPolicyErrorMessage.value = switch (error.code) {
        'invalid_bt_policy' => L10nKeys.settingsBTPolicyInvalid.tr,
        'engine_unreachable' => L10nKeys.settingsBTPolicyOffline.tr,
        _ => L10nKeys.settingsBTPolicySaveError.tr,
      };
      return false;
    } on Object {
      btPolicyErrorMessage.value = L10nKeys.settingsBTPolicySaveError.tr;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  String _messageFor(EngineClientException error) => switch (error.code) {
    'invalid_download_directory' =>
      L10nKeys.settingsDownloadDirectoryInvalid.tr,
    'engine_unreachable' => L10nKeys.settingsDownloadDirectoryOffline.tr,
    _ => L10nKeys.settingsDownloadDirectorySaveError.tr,
  };
}
