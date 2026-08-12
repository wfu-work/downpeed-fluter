import 'package:get/get.dart';

import '../../../data/clients/engine_client.dart';
import '../../../services/directory_picker.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/torrent_file_picker.dart';
import 'create_download_controller.dart';

class CreateDownloadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CreateDownloadController>(
      () => CreateDownloadController(
        client: Get.find<EngineClient>(),
        directoryPicker: Get.find<DirectoryPicker>(),
        engineSettingsService: Get.find<EngineSettingsService>(),
        torrentFilePicker: Get.find<TorrentFilePicker>(),
        initialUrl: Get.arguments is String ? Get.arguments as String : '',
      ),
    );
  }
}
