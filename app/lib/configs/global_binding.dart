import 'package:get/get.dart';

import 'dependency_registrar.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    DependencyRegistrar.registerServices();
  }
}
