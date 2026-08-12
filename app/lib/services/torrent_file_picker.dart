import 'package:file_selector/file_selector.dart';

const maxTorrentMetadataBytes = 8 << 20;

class PickedTorrentFile {
  const PickedTorrentFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

abstract interface class TorrentFilePicker {
  Future<PickedTorrentFile?> chooseTorrent();
}

class SystemTorrentFilePicker implements TorrentFilePicker {
  const SystemTorrentFilePicker();

  @override
  Future<PickedTorrentFile?> chooseTorrent() async {
    const types = XTypeGroup(
      label: 'BitTorrent metadata',
      extensions: <String>['torrent'],
      mimeTypes: <String>['application/x-bittorrent'],
      uniformTypeIdentifiers: <String>['org.bittorrent.torrent'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[types]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxTorrentMetadataBytes) {
      throw const TorrentFileTooLargeException();
    }
    return PickedTorrentFile(name: file.name, bytes: bytes);
  }
}

class TorrentFileTooLargeException implements Exception {
  const TorrentFileTooLargeException();
}
