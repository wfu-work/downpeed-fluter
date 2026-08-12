import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../domains/engine_info.dart';
import 'embedded_engine_service.dart';

class EngineService extends GetxService {
  EngineService({required this.client});

  static EngineService get to => Get.find<EngineService>();

  final EngineClient client;
  final state = EngineConnectionState.checking.obs;
  final info = Rxn<EngineInfo>();
  final errorMessage = RxnString();
  bool _refreshing = false;

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state.value = EngineConnectionState.checking;
    errorMessage.value = null;
    try {
      if (Get.isRegistered<EmbeddedEngineService>()) {
        final embeddedEngine = EmbeddedEngineService.to;
        if (embeddedEngine.state.value == EmbeddedEngineState.idle ||
            embeddedEngine.state.value == EmbeddedEngineState.failed) {
          await embeddedEngine.initialize();
        }
      }
      info.value = await _fetchInfoWithAutoFallback();
      state.value = EngineConnectionState.online;
    } on EngineClientException catch (error) {
      info.value = null;
      errorMessage.value = Get.isRegistered<EmbeddedEngineService>()
          ? EmbeddedEngineService.to.errorMessage.value ?? error.message
          : error.message;
      state.value = EngineConnectionState.offline;
    } on Object {
      info.value = null;
      errorMessage.value = Get.isRegistered<EmbeddedEngineService>()
          ? EmbeddedEngineService.to.errorMessage.value ??
                'The local Downpeed engine is not reachable.'
          : 'The local Downpeed engine is not reachable.';
      state.value = EngineConnectionState.offline;
    } finally {
      _refreshing = false;
    }
  }

  Future<EngineInfo> _fetchInfoWithAutoFallback() async {
    try {
      return await client.fetchInfo();
    } on EngineClientException {
      if (!Get.isRegistered<EmbeddedEngineService>()) rethrow;
      final embeddedEngine = EmbeddedEngineService.to;
      if (embeddedEngine.mode != EmbeddedEngineMode.auto ||
          embeddedEngine.state.value != EmbeddedEngineState.external) {
        rethrow;
      }
      await embeddedEngine.initialize();
      if (embeddedEngine.state.value != EmbeddedEngineState.running) rethrow;
      return client.fetchInfo();
    }
  }
}
