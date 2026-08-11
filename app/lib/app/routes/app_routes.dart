part of 'app_pages.dart';

abstract class Routes {
  static const tasks = '/tasks';
  static const createDownload = '/tasks/new';
  static const taskDetail = '/tasks/:id';
  static const settings = '/settings';

  static String taskDetailFor(String id) => '/tasks/${Uri.encodeComponent(id)}';

  const Routes._();
}
