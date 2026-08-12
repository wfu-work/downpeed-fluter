import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'l10n_keys.dart';

class LocalizationService extends Translations {
  static const initialLocale = Locale('zh', 'CN');
  static const fallbackLocale = Locale('en', 'US');

  @override
  Map<String, Map<String, String>> get keys => const {
    'zh_CN': {
      L10nKeys.appName: 'Downpeed',
      L10nKeys.navAll: '全部任务',
      L10nKeys.navActive: '正在传输',
      L10nKeys.navCompleted: '已完成',
      L10nKeys.navIssues: '需要处理',
      L10nKeys.navSettings: '设置',
      L10nKeys.sidebarCollapse: '收起侧栏',
      L10nKeys.sidebarExpand: '展开侧栏',
      L10nKeys.sidebarThemeToLight: '切换到浅色模式',
      L10nKeys.sidebarThemeToDark: '切换到深色模式',
      L10nKeys.settingsTitle: '设置',
      L10nKeys.settingsSubtitle: '管理界面与本机偏好。',
      L10nKeys.settingsBackToTasks: '返回下载任务',
      L10nKeys.settingsBackToMenu: '返回设置菜单',
      L10nKeys.settingsNavigationPreferences: '偏好设置',
      L10nKeys.settingsNavigationSystem: '系统',
      L10nKeys.settingsAppearance: '外观',
      L10nKeys.settingsAppearanceDescription:
          '设置 Downpeed 的明暗外观和界面语言，让长时间使用更舒适。',
      L10nKeys.settingsTheme: '主题',
      L10nKeys.settingsThemeDescription: '跟随系统会随桌面外观自动切换，也可固定使用浅色或深色模式。',
      L10nKeys.settingsThemeSystem: '跟随系统',
      L10nKeys.settingsThemeLight: '浅色',
      L10nKeys.settingsThemeDark: '深色',
      L10nKeys.settingsLanguage: '语言',
      L10nKeys.settingsLanguageDescription: '切换后界面文案会立即更新，不会更改任务名称、文件名或下载内容。',
      L10nKeys.settingsLanguageChinese: '简体中文',
      L10nKeys.settingsLanguageEnglish: 'English',
      L10nKeys.settingsAppearanceNoteTitle: '外观偏好仅影响当前设备',
      L10nKeys.settingsAppearanceNoteBody:
          '主题和语言会在选择后立即生效，并保存在本机以便下次启动继续使用。这些选项不会影响正在进行的下载、任务数据或已保存文件。',
      L10nKeys.settingsLogoPreview: 'Logo 预览',
      L10nKeys.settingsLogoPreviewDescription:
          '预览 Downpeed Logo 在浅色和深色界面中的固定对比效果。',
      L10nKeys.settingsLogoPreviewLight: '浅色外观',
      L10nKeys.settingsLogoPreviewDark: '深色外观',
      L10nKeys.settingsWorkspace: '工作区',
      L10nKeys.settingsWorkspaceDescription: '调整任务工作区的侧栏状态与宽度，让常用导航保持顺手。',
      L10nKeys.settingsSidebarExpanded: '默认展开侧栏',
      L10nKeys.settingsSidebarExpandedDescription:
          '应用启动且窗口空间足够时，自动显示完整菜单、筛选入口和任务数量。',
      L10nKeys.settingsSidebarWidth: '侧栏宽度',
      L10nKeys.settingsSidebarWidthDescription:
          '在任务工作区拖动侧栏右边缘调整宽度，当前尺寸会自动保存在本机。',
      L10nKeys.settingsWorkspaceNoteTitle: '布局会随窗口宽度自动适应',
      L10nKeys.settingsWorkspaceNoteBody:
          '侧栏偏好主要用于宽屏桌面窗口。窗口变窄时，Downpeed 会自动切换为紧凑导航；重新拉宽后继续使用已保存的展开状态和宽度，不会影响任务、筛选结果或下载进度。',
      L10nKeys.settingsNotifications: '通知与快捷键',
      L10nKeys.settingsNotificationsDescription: '管理下载完成提醒和任务工作区的常用键盘操作。',
      L10nKeys.settingsCompletionNotifications: '下载完成通知',
      L10nKeys.settingsCompletionNotificationsDescription:
          '当运行中的任务首次进入完成状态时，发送一次系统通知。',
      L10nKeys.settingsNewDownloadShortcut: '新建下载快捷键',
      L10nKeys.settingsNewDownloadShortcutDescription:
          '在任务工作区按下快捷键，可直接打开新建下载窗口。',
      L10nKeys.settingsNotificationsNoteTitle: '通知权限由当前系统管理',
      L10nKeys.settingsNotificationsNoteBody:
          '关闭此选项会立即停止 Downpeed 发送新的完成通知，不影响下载任务。如果已在系统设置中拒绝通知权限，还需在系统中重新允许。',
      L10nKeys.settingsReset: '恢复默认',
      L10nKeys.settingsEngine: '本机引擎',
      L10nKeys.settingsEngineDescription: '本机引擎负责下载调度与文件写入，未连接时可使用右侧按钮重新检查。',
      L10nKeys.settingsEngineSectionDescription:
          '查看本机下载服务的连接状态与版本，确认任务列表和实时进度能否正常同步。',
      L10nKeys.settingsEngineNoteTitle: '下载任务由本机引擎处理',
      L10nKeys.settingsEngineNoteBody:
          '本机引擎负责链接解析、队列调度、断点续传和文件写入，界面只读取并显示它的状态。使用刷新按钮只会重新检查连接，不会暂停、重启或修改下载任务。',
      L10nKeys.settingsAbout: '关于与许可证',
      L10nKeys.settingsAboutDescription: '查看应用、引擎与运行环境版本，以及开源组件的许可信息。',
      L10nKeys.settingsAboutAppVersion: 'Downpeed 客户端',
      L10nKeys.settingsAboutAppVersionDescription: '当前安装的桌面客户端版本。',
      L10nKeys.settingsAboutEngineVersion: '本机引擎版本',
      L10nKeys.settingsAboutEngineVersionDescription: 'API @api · @platform',
      L10nKeys.settingsAboutEngineUnavailable: '连接本机引擎后显示版本与运行环境。',
      L10nKeys.settingsAboutLicenses: '开源许可证',
      L10nKeys.settingsAboutLicensesDescription:
          '查看 Flutter 客户端使用的开源软件包及其许可文本。',
      L10nKeys.settingsAboutOpenLicenses: '查看许可证',
      L10nKeys.settingsAboutNoteTitle: '版本信息可用于问题诊断',
      L10nKeys.settingsAboutNoteBody:
          '反馈问题时，请同时提供客户端版本、引擎版本和 API 版本。许可证页只展示已随客户端编译的依赖。',
      L10nKeys.tasksTitle: '下载任务',
      L10nKeys.tasksSubtitle: '查看进度、速度和需要处理的任务。',
      L10nKeys.tasksAdd: '新建下载',
      L10nKeys.tasksSearch: '搜索',
      L10nKeys.tasksSort: '任务排序',
      L10nKeys.tasksSortNewest: '最新创建',
      L10nKeys.tasksSortOldest: '最早创建',
      L10nKeys.tasksSortName: '文件名',
      L10nKeys.tasksSortProgress: '进度优先',
      L10nKeys.tasksSortSize: '体积优先',
      L10nKeys.tasksSelectAll: '选择当前结果',
      L10nKeys.tasksSelected: '已选择 @count 项',
      L10nKeys.tasksClearSelection: '清除选择',
      L10nKeys.tasksBatchPause: '批量暂停',
      L10nKeys.tasksBatchResume: '批量继续',
      L10nKeys.tasksBatchCancel: '批量取消',
      L10nKeys.tasksBatchComplete: '已更新 @count 个任务。',
      L10nKeys.tasksBatchPartial: '@failed 个任务未能更新，已保留选择。',
      L10nKeys.tasksNoMatchesTitle: '当前视图没有任务',
      L10nKeys.tasksNoMatchesBody: '更换筛选条件，或清除搜索关键词。',
      L10nKeys.tasksEmptyTitle: '还没有下载任务',
      L10nKeys.tasksEmptyBody: '粘贴下载链接或新建任务，下载进度会显示在这里。',
      L10nKeys.tasksEmptyHint: '下载由本机引擎处理',
      L10nKeys.tasksPaste: '粘贴链接',
      L10nKeys.tasksComingSoon: '新建下载将在 M1 里程碑开放。',
      L10nKeys.tasksLoading: '正在读取任务',
      L10nKeys.tasksLoadError: '暂时无法读取任务列表',
      L10nKeys.tasksCount: '@count 个任务',
      L10nKeys.engineChecking: '正在连接引擎',
      L10nKeys.engineOnline: '已连接',
      L10nKeys.engineOffline: '未连接',
      L10nKeys.engineOfflineTitle: '引擎未连接',
      L10nKeys.engineOfflineBody: '启动本地 Go 服务后即可管理下载任务。',
      L10nKeys.engineRetry: '重新连接',
      L10nKeys.engineVersion: '本机引擎 · @version',
      L10nKeys.createBack: '返回任务',
      L10nKeys.createEyebrow: '新建下载 · HTTP / HTTPS',
      L10nKeys.createTitle: '检查下载链接',
      L10nKeys.createSubtitle: '粘贴一个或多行链接，确认文件信息后统一加入任务队列。',
      L10nKeys.createUrlLabel: '下载地址',
      L10nKeys.createUrlHint:
          'https://example.com/archive.zip\n每行一个链接，最多 100 个',
      L10nKeys.createResolve: '解析链接',
      L10nKeys.createResolving: '正在检查远端文件',
      L10nKeys.createResolvingBody: '读取文件名、大小与断点续传能力。',
      L10nKeys.createIdleHint: '链接只会发送给本机 Downpeed 引擎进行检查。',
      L10nKeys.createAdvanced: '高级请求选项',
      L10nKeys.createAdvancedBody: '自定义 Header、Cookie 与代理将在任务创建步骤开放。',
      L10nKeys.createResolvedTitle: '链接可以使用',
      L10nKeys.createResolvedBody: '远端文件已完成探测，尚未开始下载。',
      L10nKeys.createFileName: '文件名',
      L10nKeys.createSourceHost: '最终来源',
      L10nKeys.createFileSize: '文件大小',
      L10nKeys.createContentType: '内容类型',
      L10nKeys.createRange: '断点续传',
      L10nKeys.createRangeYes: '支持 Range',
      L10nKeys.createRangeNo: '未确认支持',
      L10nKeys.createUnknown: '服务器未提供',
      L10nKeys.createNextTitle: '下一步：选择保存位置',
      L10nKeys.createNextBody: '当前切片止于链接解析；任务创建与实际下载将在 M1 下一步接入。',
      L10nKeys.createFailedTitle: '暂时无法解析',
      L10nKeys.createInvalidUrl: '请输入包含 http:// 或 https:// 的完整下载地址。',
      L10nKeys.createInvalidScheme: '目前只支持 HTTP 和 HTTPS 链接。',
      L10nKeys.createEngineOffline: '本机下载引擎未连接，请启动引擎后重试。',
      L10nKeys.createResolveError: '远端服务器未能返回文件信息，请检查链接或稍后重试。',
      L10nKeys.createResponseError: '引擎返回了无法识别的文件信息，请更新应用后重试。',
      L10nKeys.createBatchLimit: '一次最多处理 100 个去重后的下载链接。',
      L10nKeys.createBatchResolveNone: '这些链接都未能解析，请逐项检查后重试。',
      L10nKeys.createBatchResolvedTitle: '已解析 @count 个文件',
      L10nKeys.createBatchResolvedBody: '可用文件将使用同一个保存位置加入队列。',
      L10nKeys.createBatchResolveFailed: '@count 个链接未能解析',
      L10nKeys.createBatchDestination: '@count 个文件将保存到此目录',
      L10nKeys.createStartBatch: '创建 @count 个任务',
      L10nKeys.createBatchCreatedTitle: '批量任务已提交',
      L10nKeys.createBatchCreatedBody: 'Go 引擎已接管成功项，队列与并发调度会继续运行。',
      L10nKeys.createBatchCreatedSummary: '成功 @succeeded 个 · 失败 @failed 个',
      L10nKeys.createBatchFailuresTitle: '需要处理的项目',
      L10nKeys.createSaveDirectory: '保存位置',
      L10nKeys.createChooseDirectory: '选择文件夹',
      L10nKeys.createChangeDirectory: '更改位置',
      L10nKeys.createDirectoryRequired: '开始下载前，请先选择保存文件夹。',
      L10nKeys.createDirectoryError: '无法使用这个文件夹，请重新选择一个本机目录。',
      L10nKeys.createDestinationExists: '同名文件已经存在，请更换保存位置。',
      L10nKeys.createStartDownload: '开始下载',
      L10nKeys.createCreating: '正在创建下载任务',
      L10nKeys.createCreatingBody: '本机引擎正在把任务加入传输队列。',
      L10nKeys.createTaskError: '无法创建下载任务，请检查引擎状态后重试。',
      L10nKeys.createCancelError: '任务暂时无法取消，请稍后重试。',
      L10nKeys.createEventsInterrupted: '实时进度连接已中断，任务仍会在引擎中继续。',
      L10nKeys.taskQueued: '等待传输',
      L10nKeys.taskQueuedBody: '任务已进入队列，会在并发槽位可用时自动开始。',
      L10nKeys.taskDownloading: '正在传输',
      L10nKeys.taskDownloadingBody: '保持窗口打开可查看实时进度，关闭页面不会中断任务。',
      L10nKeys.taskRetrying: '等待重试',
      L10nKeys.taskRetryingBody: '网络传输暂时中断，引擎将按退避时间自动重试。',
      L10nKeys.taskPaused: '已暂停',
      L10nKeys.taskPausedBody: '已保留当前进度，可以从断点继续传输。',
      L10nKeys.taskCompleted: '下载完成',
      L10nKeys.taskCompletedBody: '文件已写入所选位置。',
      L10nKeys.taskCanceled: '下载已取消',
      L10nKeys.taskCanceledBody: '未完成文件已从目标位置清理。',
      L10nKeys.taskFailed: '下载未完成',
      L10nKeys.taskFailedBody: '引擎已停止传输，文件没有被保留。',
      L10nKeys.taskProgress: '已传输',
      L10nKeys.taskSpeed: '实时速度',
      L10nKeys.taskDestination: '保存到',
      L10nKeys.taskCancel: '取消下载',
      L10nKeys.taskCanceling: '正在取消',
      L10nKeys.taskPause: '暂停',
      L10nKeys.taskResume: '继续',
      L10nKeys.taskOpenFile: '打开文件',
      L10nKeys.taskRevealFile: '在文件管理器中显示',
      L10nKeys.taskDetails: '任务详情',
      L10nKeys.taskSource: '来源',
      L10nKeys.taskCreated: '创建时间',
      L10nKeys.taskNoSelection: '选择一个任务',
      L10nKeys.taskNoSelectionBody: '查看传输进度、保存位置和可用操作。',
      L10nKeys.taskNotFound: '任务不存在或已被移除。',
      L10nKeys.taskUnknownTotal: '@downloaded · 总大小未知',
      L10nKeys.taskDestinationExists: '目标位置已有同名文件，请更换文件夹后重新创建。',
      L10nKeys.taskInvalidDestination: '保存位置不可用或没有写入权限。',
      L10nKeys.taskRemoteRejected: '远端服务器拒绝了下载请求，请检查链接权限。',
      L10nKeys.taskRemoteChanged: '远端文件已更新。为避免拼接新旧内容，Downpeed 已停止续传，请重新创建任务。',
      L10nKeys.taskDownloadFailed: '网络传输提前中断，请稍后重新创建任务。',
      L10nKeys.taskResumeNotSupported: '远端服务器不支持安全续传，当前分片未被拼接。',
      L10nKeys.taskPartialFileChanged: '未完成文件已被其他程序修改，无法安全继续。',
      L10nKeys.taskFileConsistencyFailed: '远端响应与预期文件结构不一致，最终文件没有发布。',
      L10nKeys.taskAtomicPublishFailed: '保存位置不支持安全发布完整文件，请更换本机磁盘目录后重新下载。',
      L10nKeys.taskFileActionNotFound: '文件已被移动或删除，无法执行此操作。',
      L10nKeys.taskFileActionUnavailable: '系统暂时无法打开这个文件，请检查文件权限后重试。',
      L10nKeys.taskFileActionUnsupported: '当前平台暂不支持这个文件操作。',
      L10nKeys.notificationDownloadComplete: '下载完成',
      L10nKeys.notificationDownloadCompleteBody: '@fileName 已保存到所选位置。',
    },
    'en_US': {
      L10nKeys.appName: 'Downpeed',
      L10nKeys.navAll: 'All transfers',
      L10nKeys.navActive: 'Active',
      L10nKeys.navCompleted: 'Completed',
      L10nKeys.navIssues: 'Needs attention',
      L10nKeys.navSettings: 'Settings',
      L10nKeys.sidebarCollapse: 'Collapse sidebar',
      L10nKeys.sidebarExpand: 'Expand sidebar',
      L10nKeys.sidebarThemeToLight: 'Switch to light mode',
      L10nKeys.sidebarThemeToDark: 'Switch to dark mode',
      L10nKeys.settingsTitle: 'Settings',
      L10nKeys.settingsSubtitle: 'Manage local preferences.',
      L10nKeys.settingsBackToTasks: 'Back to transfers',
      L10nKeys.settingsBackToMenu: 'Back to settings',
      L10nKeys.settingsNavigationPreferences: 'Preferences',
      L10nKeys.settingsNavigationSystem: 'System',
      L10nKeys.settingsAppearance: 'Appearance',
      L10nKeys.settingsAppearanceDescription:
          'Choose how Downpeed looks and reads for a more comfortable workspace.',
      L10nKeys.settingsTheme: 'Theme',
      L10nKeys.settingsThemeDescription:
          'Follow your desktop appearance automatically, or keep light or dark mode on.',
      L10nKeys.settingsThemeSystem: 'System',
      L10nKeys.settingsThemeLight: 'Light',
      L10nKeys.settingsThemeDark: 'Dark',
      L10nKeys.settingsLanguage: 'Language',
      L10nKeys.settingsLanguageDescription:
          'Interface copy updates immediately without changing task names, file names, or downloads.',
      L10nKeys.settingsLanguageChinese: '简体中文',
      L10nKeys.settingsLanguageEnglish: 'English',
      L10nKeys.settingsAppearanceNoteTitle:
          'Appearance preferences stay on this device',
      L10nKeys.settingsAppearanceNoteBody:
          'Theme and language changes apply immediately and are saved locally for your next launch. They do not affect active downloads, task data, or saved files.',
      L10nKeys.settingsLogoPreview: 'Logo preview',
      L10nKeys.settingsLogoPreviewDescription:
          'Preview the fixed Downpeed logo contrast on light and dark interface surfaces.',
      L10nKeys.settingsLogoPreviewLight: 'Light appearance',
      L10nKeys.settingsLogoPreviewDark: 'Dark appearance',
      L10nKeys.settingsWorkspace: 'Workspace',
      L10nKeys.settingsWorkspaceDescription:
          'Tune the transfer workspace sidebar so everyday navigation stays comfortable.',
      L10nKeys.settingsSidebarExpanded: 'Expand sidebar by default',
      L10nKeys.settingsSidebarExpandedDescription:
          'Show the full menu, filters, and task counts at launch when the window has enough room.',
      L10nKeys.settingsSidebarWidth: 'Sidebar width',
      L10nKeys.settingsSidebarWidthDescription:
          'Drag the sidebar edge in the transfer workspace. Its current size is saved on this device.',
      L10nKeys.settingsWorkspaceNoteTitle:
          'The layout adapts to the window width',
      L10nKeys.settingsWorkspaceNoteBody:
          'Sidebar preferences apply to wide desktop windows. Downpeed switches to compact navigation when space is limited and restores your saved width and expanded state when the window grows, without affecting tasks, filters, or download progress.',
      L10nKeys.settingsNotifications: 'Notifications & shortcuts',
      L10nKeys.settingsNotificationsDescription:
          'Manage completion alerts and common keyboard actions in the transfer workspace.',
      L10nKeys.settingsCompletionNotifications:
          'Download completion notifications',
      L10nKeys.settingsCompletionNotificationsDescription:
          'Send one system notification when an active task first reaches the completed state.',
      L10nKeys.settingsNewDownloadShortcut: 'New download shortcut',
      L10nKeys.settingsNewDownloadShortcutDescription:
          'Open the new download dialog directly from the transfer workspace.',
      L10nKeys.settingsNotificationsNoteTitle:
          'Notification permission is managed by your system',
      L10nKeys.settingsNotificationsNoteBody:
          'Turning this off immediately stops new Downpeed completion notifications without affecting downloads. If permission was denied in system settings, allow it there before notifications can appear.',
      L10nKeys.settingsReset: 'Reset',
      L10nKeys.settingsEngine: 'Local engine',
      L10nKeys.settingsEngineDescription:
          'The local engine schedules downloads and writes files. Use the button on the right to check the connection again.',
      L10nKeys.settingsEngineSectionDescription:
          'Review the local download service connection and version to confirm tasks and live progress can stay in sync.',
      L10nKeys.settingsEngineNoteTitle:
          'Downloads are handled by the local engine',
      L10nKeys.settingsEngineNoteBody:
          'The local engine resolves links, schedules the queue, resumes transfers, and writes files while the interface reads and presents its state. Refresh only checks the connection again; it does not pause, restart, or modify downloads.',
      L10nKeys.settingsAbout: 'About & licenses',
      L10nKeys.settingsAboutDescription:
          'Review app, engine, and runtime versions together with open-source license information.',
      L10nKeys.settingsAboutAppVersion: 'Downpeed client',
      L10nKeys.settingsAboutAppVersionDescription:
          'The currently installed desktop client version.',
      L10nKeys.settingsAboutEngineVersion: 'Local engine version',
      L10nKeys.settingsAboutEngineVersionDescription: 'API @api · @platform',
      L10nKeys.settingsAboutEngineUnavailable:
          'Connect the local engine to view its version and runtime.',
      L10nKeys.settingsAboutLicenses: 'Open-source licenses',
      L10nKeys.settingsAboutLicensesDescription:
          'Review the open-source packages compiled into the Flutter client and their license text.',
      L10nKeys.settingsAboutOpenLicenses: 'View licenses',
      L10nKeys.settingsAboutNoteTitle: 'Version details help diagnose problems',
      L10nKeys.settingsAboutNoteBody:
          'When reporting an issue, include the client, engine, and API versions. The license page lists dependencies compiled into the client.',
      L10nKeys.tasksTitle: 'Transfers',
      L10nKeys.tasksSubtitle:
          'Review progress, speed, and tasks that need attention.',
      L10nKeys.tasksAdd: 'New download',
      L10nKeys.tasksSearch: 'Search',
      L10nKeys.tasksSort: 'Sort transfers',
      L10nKeys.tasksSortNewest: 'Newest first',
      L10nKeys.tasksSortOldest: 'Oldest first',
      L10nKeys.tasksSortName: 'File name',
      L10nKeys.tasksSortProgress: 'Progress',
      L10nKeys.tasksSortSize: 'File size',
      L10nKeys.tasksSelectAll: 'Select current results',
      L10nKeys.tasksSelected: '@count selected',
      L10nKeys.tasksClearSelection: 'Clear selection',
      L10nKeys.tasksBatchPause: 'Pause selected',
      L10nKeys.tasksBatchResume: 'Resume selected',
      L10nKeys.tasksBatchCancel: 'Cancel selected',
      L10nKeys.tasksBatchComplete: 'Updated @count tasks.',
      L10nKeys.tasksBatchPartial:
          '@failed tasks could not be updated and remain selected.',
      L10nKeys.tasksNoMatchesTitle: 'No tasks in this view',
      L10nKeys.tasksNoMatchesBody:
          'Choose another filter or clear the search query.',
      L10nKeys.tasksEmptyTitle: 'No downloads yet',
      L10nKeys.tasksEmptyBody:
          'Paste a download link or create a task. Progress will appear here.',
      L10nKeys.tasksEmptyHint: 'Downloads are handled by the local engine',
      L10nKeys.tasksPaste: 'Paste link',
      L10nKeys.tasksComingSoon: 'New downloads arrive with the M1 milestone.',
      L10nKeys.tasksLoading: 'Loading transfers',
      L10nKeys.tasksLoadError: 'Could not load transfers',
      L10nKeys.tasksCount: '@count tasks',
      L10nKeys.engineChecking: 'Connecting to engine',
      L10nKeys.engineOnline: 'Connected',
      L10nKeys.engineOffline: 'Disconnected',
      L10nKeys.engineOfflineTitle: 'Engine not connected',
      L10nKeys.engineOfflineBody:
          'Start the local Go service to manage downloads.',
      L10nKeys.engineRetry: 'Reconnect',
      L10nKeys.engineVersion: 'Local engine · @version',
      L10nKeys.createBack: 'Back to transfers',
      L10nKeys.createEyebrow: 'New download · HTTP / HTTPS',
      L10nKeys.createTitle: 'Inspect a download link',
      L10nKeys.createSubtitle:
          'Paste one or more links, inspect them, then add the files to one queue.',
      L10nKeys.createUrlLabel: 'Download URL',
      L10nKeys.createUrlHint:
          'https://example.com/archive.zip\nOne link per line, up to 100',
      L10nKeys.createResolve: 'Inspect link',
      L10nKeys.createResolving: 'Inspecting the remote file',
      L10nKeys.createResolvingBody:
          'Reading its name, size, and resume capability.',
      L10nKeys.createIdleHint:
          'The link is inspected only by your local Downpeed engine.',
      L10nKeys.createAdvanced: 'Advanced request options',
      L10nKeys.createAdvancedBody:
          'Custom headers, cookies, and proxies arrive with task creation.',
      L10nKeys.createResolvedTitle: 'The link is ready',
      L10nKeys.createResolvedBody:
          'The remote file has been inspected. No download has started.',
      L10nKeys.createFileName: 'File name',
      L10nKeys.createSourceHost: 'Final source',
      L10nKeys.createFileSize: 'File size',
      L10nKeys.createContentType: 'Content type',
      L10nKeys.createRange: 'Resume support',
      L10nKeys.createRangeYes: 'Range supported',
      L10nKeys.createRangeNo: 'Not confirmed',
      L10nKeys.createUnknown: 'Not provided',
      L10nKeys.createNextTitle: 'Next: choose a save location',
      L10nKeys.createNextBody:
          'This slice ends at link inspection. Task creation and downloading follow in the next M1 step.',
      L10nKeys.createFailedTitle: 'Could not inspect this link',
      L10nKeys.createInvalidUrl:
          'Enter a complete download URL beginning with http:// or https://.',
      L10nKeys.createInvalidScheme:
          'Only HTTP and HTTPS links are supported right now.',
      L10nKeys.createEngineOffline:
          'The local engine is offline. Start it and try again.',
      L10nKeys.createResolveError:
          'The remote server did not return file details. Check the link or try again.',
      L10nKeys.createResponseError:
          'The engine returned file details this app cannot read. Update the app and try again.',
      L10nKeys.createBatchLimit:
          'A batch can contain up to 100 unique download links.',
      L10nKeys.createBatchResolveNone:
          'None of these links could be inspected. Review each one and try again.',
      L10nKeys.createBatchResolvedTitle: '@count files inspected',
      L10nKeys.createBatchResolvedBody:
          'Ready files will enter the queue with one shared save location.',
      L10nKeys.createBatchResolveFailed: '@count links could not be inspected',
      L10nKeys.createBatchDestination:
          '@count files will be saved in this folder',
      L10nKeys.createStartBatch: 'Create @count tasks',
      L10nKeys.createBatchCreatedTitle: 'Batch submitted',
      L10nKeys.createBatchCreatedBody:
          'The Go engine now owns successful tasks and continues queue scheduling.',
      L10nKeys.createBatchCreatedSummary:
          '@succeeded succeeded · @failed failed',
      L10nKeys.createBatchFailuresTitle: 'Items that need attention',
      L10nKeys.createSaveDirectory: 'Save location',
      L10nKeys.createChooseDirectory: 'Choose folder',
      L10nKeys.createChangeDirectory: 'Change location',
      L10nKeys.createDirectoryRequired:
          'Choose a save folder before starting the download.',
      L10nKeys.createDirectoryError:
          'This folder cannot be used. Choose another local directory.',
      L10nKeys.createDestinationExists:
          'A file with this name already exists. Choose another location.',
      L10nKeys.createStartDownload: 'Start download',
      L10nKeys.createCreating: 'Creating the download task',
      L10nKeys.createCreatingBody:
          'The local engine is adding the task to the transfer queue.',
      L10nKeys.createTaskError:
          'Could not create the task. Check the engine and try again.',
      L10nKeys.createCancelError:
          'The task cannot be canceled right now. Try again shortly.',
      L10nKeys.createEventsInterrupted:
          'Live progress was interrupted. The task continues in the engine.',
      L10nKeys.taskQueued: 'Waiting to transfer',
      L10nKeys.taskQueuedBody:
          'The task is queued and starts when a concurrency slot is available.',
      L10nKeys.taskDownloading: 'Transferring',
      L10nKeys.taskDownloadingBody:
          'Keep this page open for live progress. Leaving does not stop the task.',
      L10nKeys.taskRetrying: 'Waiting to retry',
      L10nKeys.taskRetryingBody:
          'The transfer was interrupted. The engine will retry after backoff.',
      L10nKeys.taskPaused: 'Paused',
      L10nKeys.taskPausedBody:
          'Current progress is preserved and ready to resume.',
      L10nKeys.taskCompleted: 'Download complete',
      L10nKeys.taskCompletedBody:
          'The file was written to your chosen location.',
      L10nKeys.taskCanceled: 'Download canceled',
      L10nKeys.taskCanceledBody:
          'The incomplete file was removed from the destination.',
      L10nKeys.taskFailed: 'Download did not finish',
      L10nKeys.taskFailedBody:
          'The engine stopped the transfer and did not keep the file.',
      L10nKeys.taskProgress: 'Transferred',
      L10nKeys.taskSpeed: 'Live speed',
      L10nKeys.taskDestination: 'Save to',
      L10nKeys.taskCancel: 'Cancel download',
      L10nKeys.taskCanceling: 'Canceling',
      L10nKeys.taskPause: 'Pause',
      L10nKeys.taskResume: 'Resume',
      L10nKeys.taskOpenFile: 'Open file',
      L10nKeys.taskRevealFile: 'Show in file manager',
      L10nKeys.taskDetails: 'Task details',
      L10nKeys.taskSource: 'Source',
      L10nKeys.taskCreated: 'Created',
      L10nKeys.taskNoSelection: 'Select a transfer',
      L10nKeys.taskNoSelectionBody:
          'Inspect its progress, destination, and available controls.',
      L10nKeys.taskNotFound: 'This task does not exist or was removed.',
      L10nKeys.taskUnknownTotal: '@downloaded · total unknown',
      L10nKeys.taskDestinationExists:
          'The destination already has this file. Choose another folder and create it again.',
      L10nKeys.taskInvalidDestination:
          'The save location is unavailable or not writable.',
      L10nKeys.taskRemoteRejected:
          'The remote server rejected the request. Check access to the link.',
      L10nKeys.taskRemoteChanged:
          'The remote file changed. Downpeed stopped before mixing old and new bytes; create a new task.',
      L10nKeys.taskDownloadFailed:
          'The network transfer ended early. Create the task again later.',
      L10nKeys.taskResumeNotSupported:
          'The server cannot safely resume this transfer. No bytes were appended.',
      L10nKeys.taskPartialFileChanged:
          'The partial file changed outside Downpeed and cannot be resumed safely.',
      L10nKeys.taskFileConsistencyFailed:
          'The remote response did not match the expected file layout. No final file was published.',
      L10nKeys.taskAtomicPublishFailed:
          'This location cannot publish the completed file safely. Choose another local disk folder.',
      L10nKeys.taskFileActionNotFound:
          'The file was moved or deleted and can no longer be opened.',
      L10nKeys.taskFileActionUnavailable:
          'The system could not open this file. Check its permissions and try again.',
      L10nKeys.taskFileActionUnsupported:
          'This file action is not supported on the current platform.',
      L10nKeys.notificationDownloadComplete: 'Download complete',
      L10nKeys.notificationDownloadCompleteBody:
          '@fileName was saved to your chosen location.',
    },
  };
}
