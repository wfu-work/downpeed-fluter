import 'dart:async';

import 'package:get/get.dart';

import '../configs/localization/l10n_keys.dart';
import '../data/clients/engine_client.dart';
import '../domains/engine_settings.dart';
import 'engine_settings_service.dart';
import 'proxy_credential_store.dart';

class ProxySettingsService extends GetxService {
  ProxySettingsService({
    required this.client,
    required this.engineSettings,
    required this.credentialStore,
  });

  static ProxySettingsService get to => Get.find<ProxySettingsService>();

  final EngineClient client;
  final EngineSettingsService engineSettings;
  final ProxyCredentialStore credentialStore;
  final isInitializing = false.obs;
  final isSaving = false.obs;
  final isTesting = false.obs;
  final credentialStoreAvailable = true.obs;
  final hasStoredPassword = false.obs;
  final errorMessage = RxnString();
  final testErrorMessage = RxnString();
  final testResult = Rxn<ProxyTestResult>();

  String _password = '';
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (isInitializing.value) return;
    isInitializing.value = true;
    String password;
    try {
      password = await credentialStore.read() ?? '';
    } on Object {
      credentialStoreAvailable.value = false;
      errorMessage.value = L10nKeys.settingsProxyCredentialUnavailable.tr;
      isInitializing.value = false;
      return;
    }
    _password = password;
    hasStoredPassword.value = password.isNotEmpty;
    credentialStoreAvailable.value = true;
    try {
      if (password.isNotEmpty) await client.updateProxyCredential(password);
      _initialized = true;
    } on Object {
      errorMessage.value = L10nKeys.settingsProxyOffline.tr;
    } finally {
      isInitializing.value = false;
    }
  }

  Future<bool> save(
    ProxySettings settings, {
    String? replacementPassword,
  }) async {
    if (isSaving.value || engineSettings.isSaving.value) return false;
    isSaving.value = true;
    errorMessage.value = null;
    testErrorMessage.value = null;
    testResult.value = null;
    final previousSettings = engineSettings.proxy;
    final previousPassword = _password;
    final nextPassword = replacementPassword ?? previousPassword;
    var credentialChanged = false;
    try {
      if (replacementPassword != null) {
        if (replacementPassword.isEmpty) {
          await credentialStore.delete();
        } else {
          await credentialStore.write(replacementPassword);
        }
        credentialChanged = true;
        credentialStoreAvailable.value = true;
      }
      final settingsUpdated = await engineSettings.updateProxySettings(
        settings,
      );
      if (!settingsUpdated) {
        throw const EngineClientException(
          'Proxy settings were not accepted.',
          code: 'proxy_settings_save_failed',
        );
      }
      await client.updateProxyCredential(nextPassword);
      _password = nextPassword;
      hasStoredPassword.value = nextPassword.isNotEmpty;
      return true;
    } on Object catch (error) {
      if (replacementPassword != null &&
          !credentialChanged &&
          error is! EngineClientException) {
        credentialStoreAvailable.value = false;
      }
      if (previousSettings != null &&
          engineSettings.proxy != previousSettings) {
        await engineSettings.updateProxySettings(previousSettings);
        try {
          await client.updateProxyCredential(previousPassword);
        } on Object {
          // The next app startup will reapply the credential from secure storage.
        }
      }
      if (credentialChanged) {
        try {
          if (previousPassword.isEmpty) {
            await credentialStore.delete();
          } else {
            await credentialStore.write(previousPassword);
          }
        } on Object {
          credentialStoreAvailable.value = false;
        }
      }
      errorMessage.value = _saveMessageFor(error);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> clearCredential() async {
    if (!hasStoredPassword.value) return true;
    final settings = engineSettings.proxy;
    if (settings == null) return false;
    return save(settings, replacementPassword: '');
  }

  Future<bool> test() async {
    if (isTesting.value) return false;
    isTesting.value = true;
    testErrorMessage.value = null;
    testResult.value = null;
    try {
      testResult.value = await client.testProxy();
      return true;
    } on EngineClientException catch (error) {
      testErrorMessage.value = switch (error.code) {
        'proxy_authentication_failed' =>
          L10nKeys.settingsProxyTestAuthenticationFailed.tr,
        'proxy_test_timeout' => L10nKeys.settingsProxyTestTimeout.tr,
        'engine_unreachable' => L10nKeys.settingsProxyOffline.tr,
        _ => L10nKeys.settingsProxyTestConnectionFailed.tr,
      };
      return false;
    } on Object {
      testErrorMessage.value = L10nKeys.settingsProxyTestConnectionFailed.tr;
      return false;
    } finally {
      isTesting.value = false;
    }
  }

  String _saveMessageFor(Object error) {
    if (!credentialStoreAvailable.value) {
      return L10nKeys.settingsProxyCredentialUnavailable.tr;
    }
    if (error is EngineClientException) {
      return switch (error.code) {
        'invalid_proxy_settings' => L10nKeys.settingsProxyInvalid.tr,
        'engine_unreachable' => L10nKeys.settingsProxyOffline.tr,
        _ => L10nKeys.settingsProxySaveError.tr,
      };
    }
    return L10nKeys.settingsProxySaveError.tr;
  }
}
