import 'package:downpeed_flutter/services/directory_picker.dart';

class StubDirectoryPicker implements DirectoryPicker {
  const StubDirectoryPicker({this.result});

  final String? result;

  @override
  Future<String?> chooseDirectory({String? initialDirectory}) async => result;
}
