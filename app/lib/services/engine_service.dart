import 'package:get/get.dart';

import '../data/clients/engine_client.dart';
import '../domains/engine_info.dart';

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
      info.value = await client.fetchInfo();
      state.value = EngineConnectionState.online;
    } on EngineClientException catch (error) {
      info.value = null;
      errorMessage.value = error.message;
      state.value = EngineConnectionState.offline;
    } on Object {
      info.value = null;
      errorMessage.value = 'The local Downpeed engine is not reachable.';
      state.value = EngineConnectionState.offline;
    } finally {
      _refreshing = false;
    }
  }
}
