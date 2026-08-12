import 'package:downpeed_flutter/services/torrent_file_picker.dart';

class StubTorrentFilePicker implements TorrentFilePicker {
  const StubTorrentFilePicker({this.result, this.error});

  final PickedTorrentFile? result;
  final Object? error;

  @override
  Future<PickedTorrentFile?> chooseTorrent() async {
    if (error case final value?) throw value;
    return result;
  }
}
