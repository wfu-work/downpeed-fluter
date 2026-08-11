import 'package:file_selector/file_selector.dart';

abstract interface class DirectoryPicker {
  Future<String?> chooseDirectory({String? initialDirectory});
}

class SystemDirectoryPicker implements DirectoryPicker {
  const SystemDirectoryPicker();

  @override
  Future<String?> chooseDirectory({String? initialDirectory}) =>
      getDirectoryPath(initialDirectory: initialDirectory);
}
