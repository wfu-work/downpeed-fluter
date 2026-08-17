import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/pages/create_download/create_download_view.dart';

class DownloadDialogService extends GetxService {
  static DownloadDialogService get to => Get.find<DownloadDialogService>();

  bool _dialogOpen = false;

  Future<void> open({String initialUrl = ''}) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      await showCreateDownloadDialog(initialUrl: initialUrl);
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> paste() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    await open(initialUrl: clipboard?.text?.trim() ?? '');
  }
}
