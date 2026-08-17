import 'package:get/get.dart';

import '../pages/create_download/create_download_binding.dart';
import '../pages/create_download/create_download_view.dart';
import '../pages/network/network_binding.dart';
import '../pages/network/network_view.dart';
import '../pages/overview/overview_binding.dart';
import '../pages/overview/overview_view.dart';
import '../pages/settings/settings_binding.dart';
import '../pages/settings/settings_view.dart';
import '../pages/task_list/task_list_binding.dart';
import '../pages/task_list/task_list_view.dart';
import '../pages/task_detail/task_detail_binding.dart';
import '../pages/task_detail/task_detail_view.dart';

part 'app_routes.dart';

class AppPages {
  const AppPages._();

  static const initial = Routes.tasks;

  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: Routes.overview,
      page: () => const OverviewView(),
      binding: OverviewBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: Routes.tasks,
      page: () => const TaskListView(),
      binding: TaskListBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.createDownload,
      page: () => const CreateDownloadView(),
      binding: CreateDownloadBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.taskDetail,
      page: () => const TaskDetailView(),
      binding: TaskDetailBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.network,
      page: () => const NetworkView(),
      binding: NetworkBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: Routes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
      transition: Transition.noTransition,
    ),
  ];
}
