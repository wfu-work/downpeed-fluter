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
      L10nKeys.navOverview: '概览',
      L10nKeys.navTasks: '下载任务',
      L10nKeys.navNetwork: '网络',
      L10nKeys.navAll: '全部任务',
      L10nKeys.navActive: '正在传输',
      L10nKeys.navCompleted: '已完成',
      L10nKeys.navIssues: '需要处理',
      L10nKeys.navSettings: '设置',
      L10nKeys.sidebarCollapse: '收起侧栏',
      L10nKeys.sidebarExpand: '展开侧栏',
      L10nKeys.sidebarThemeToLight: '切换到浅色模式',
      L10nKeys.sidebarThemeToDark: '切换到深色模式',
      L10nKeys.overviewTitle: '概览',
      L10nKeys.overviewSubtitle: '查看当前传输、队列和最近任务。',
      L10nKeys.overviewCurrentSpeed: '当前下载速度',
      L10nKeys.overviewActive: '传输中',
      L10nKeys.overviewQueued: '排队与暂停',
      L10nKeys.overviewCompleted: '已完成',
      L10nKeys.overviewIssues: '需要处理',
      L10nKeys.overviewCurrentTransfers: '当前传输',
      L10nKeys.overviewCurrentTransfersSubtitle: '优先显示下载、重试、排队和暂停中的任务。',
      L10nKeys.overviewRecent: '最近任务',
      L10nKeys.overviewRecentSubtitle: '按最近更新时间排列。',
      L10nKeys.overviewViewAll: '查看全部任务',
      L10nKeys.overviewNewDownload: '新建下载',
      L10nKeys.overviewPasteLink: '粘贴链接',
      L10nKeys.overviewRefresh: '刷新任务',
      L10nKeys.overviewActions: '概览操作',
      L10nKeys.overviewNoActiveTitle: '当前没有进行中的任务',
      L10nKeys.overviewNoActiveBody: '队列处于空闲状态，新建任务后会在这里显示。',
      L10nKeys.overviewNoRecentTitle: '还没有最近任务',
      L10nKeys.overviewNoRecentBody: '完成一次下载后，可在这里快速回看任务状态。',
      L10nKeys.overviewActivity: '活动',
      L10nKeys.overviewActivitySubtitle: '按任务最近更新时间显示近 13 周的活跃度。',
      L10nKeys.overviewActivityLess: '少',
      L10nKeys.overviewActivityMore: '多',
      L10nKeys.overviewActivityEmpty: '完成或更新任务后，这里会显示活动记录。',
      L10nKeys.overviewActivityMonday: '周一',
      L10nKeys.overviewActivityWednesday: '周三',
      L10nKeys.overviewActivityFriday: '周五',
      L10nKeys.networkTitle: '网络',
      L10nKeys.networkSubtitle: '查看本机引擎、下载调度和受限 BitTorrent 网络边界。',
      L10nKeys.networkRefresh: '刷新引擎',
      L10nKeys.networkOpenSettings: '进入设置',
      L10nKeys.networkEngine: '本机引擎',
      L10nKeys.networkEngineSubtitle: '界面通过本机 API 读取任务与实时进度。',
      L10nKeys.networkEngineName: '引擎',
      L10nKeys.networkEngineVersion: '版本',
      L10nKeys.networkApi: 'API',
      L10nKeys.networkRuntime: '运行时',
      L10nKeys.networkPlatform: '平台',
      L10nKeys.networkScheduler: '速度与调度',
      L10nKeys.networkSchedulerSubtitle: '本机引擎当前执行的并发、带宽和故障重试策略。',
      L10nKeys.networkMaxConcurrentTasks: '最大并发任务',
      L10nKeys.networkConcurrentTasksValue: '@count 个任务',
      L10nKeys.networkDownloadRateLimit: '全局下载限速',
      L10nKeys.networkAutomaticRetries: '自动重试次数',
      L10nKeys.networkRetriesValue: '@count 次',
      L10nKeys.networkUnlimited: '不限速',
      L10nKeys.networkDownloads: '下载边界',
      L10nKeys.networkDownloadsSubtitle: '新任务的保存位置与受限 BT 连接预算。',
      L10nKeys.networkDefaultDirectory: '默认下载目录',
      L10nKeys.networkPeerBudget: '每任务 Peer 预算',
      L10nKeys.networkPeerBudgetValue: '@count 个连接',
      L10nKeys.networkPolicy: '受限网络策略',
      L10nKeys.networkPolicySubtitle: '以下能力由本机引擎执行；完成独立安全门禁前不会开放。',
      L10nKeys.networkPolicyRestricted: '受限策略正常',
      L10nKeys.networkPolicyUnexpected: '检测到非预期网络能力',
      L10nKeys.networkExplicitPeers: '仅显式公网 IPv4 Peer',
      L10nKeys.networkTrackers: 'Tracker',
      L10nKeys.networkDht: 'DHT',
      L10nKeys.networkPex: 'PEX',
      L10nKeys.networkWebSeeds: 'WebSeed',
      L10nKeys.networkIpv6: 'IPv6',
      L10nKeys.networkInbound: '入站连接',
      L10nKeys.networkUpload: '上传',
      L10nKeys.networkSeeding: '做种',
      L10nKeys.networkEnabled: '已开启',
      L10nKeys.networkDisabled: '已关闭',
      L10nKeys.networkLoading: '正在读取引擎信息…',
      L10nKeys.networkUnavailable: '连接本机引擎后显示网络信息。',
      L10nKeys.settingsTitle: '设置',
      L10nKeys.settingsSubtitle: '管理界面与本机偏好。',
      L10nKeys.settingsBackToTasks: '返回下载任务',
      L10nKeys.settingsBackToMenu: '返回设置菜单',
      L10nKeys.settingsNavigationPreferences: '偏好设置',
      L10nKeys.settingsNavigationSystem: '系统',
      L10nKeys.settingsNavigationDownloads: '下载与网络',
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
          '应用启动且窗口空间足够时，自动显示完整的概览、下载任务和网络入口。',
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
      L10nKeys.settingsCloseToTray: '关闭窗口时保留在托盘',
      L10nKeys.settingsCloseToTrayDescription: '关闭主窗口后继续运行下载；可从系统托盘恢复窗口或完整退出。',
      L10nKeys.settingsLaunchAtLogin: '登录时启动 Downpeed',
      L10nKeys.settingsLaunchAtLoginDescription: '由系统登录项管理；手动打开应用始终显示窗口。',
      L10nKeys.settingsStartHiddenOnLogin: '登录启动时静默运行',
      L10nKeys.settingsStartHiddenOnLoginDescription:
          '仅由系统登录项唤起时隐藏主窗口并留在托盘；托盘不可用时会显示窗口。',
      L10nKeys.settingsStartupUnavailableTitle: '当前系统暂不支持登录启动',
      L10nKeys.settingsStartupUnavailableBody:
          'macOS 需要 13 或更高版本；Windows 与 Linux 需要可写的当前用户登录项。手动启动不受影响。',
      L10nKeys.settingsStartupErrorTitle: '登录启动设置未更改',
      L10nKeys.settingsStartupReadError: '无法读取当前系统登录项状态，请稍后重试。',
      L10nKeys.settingsStartupUpdateError: '系统未能更新登录项，已恢复为系统当前状态。',
      L10nKeys.settingsStartupVerificationError: '系统返回的登录项状态与请求不一致，已显示实际状态。',
      L10nKeys.settingsNotificationsNoteTitle: '通知权限由当前系统管理',
      L10nKeys.settingsNotificationsNoteBody:
          '关闭此选项会立即停止 Downpeed 发送新的完成通知，不影响下载任务。如果已在系统设置中拒绝通知权限，还需在系统中重新允许。',
      L10nKeys.settingsDownloads: '下载与文件',
      L10nKeys.settingsDownloadsDescription: '设置新任务的保存位置、同名文件处理方式和本机完成动作。',
      L10nKeys.settingsDownloadDirectory: '默认下载目录',
      L10nKeys.settingsDownloadDirectoryDescription:
          '新建 HTTP 下载时会自动使用此目录，仍可在单个任务中临时更改。',
      L10nKeys.settingsDownloadDirectoryChange: '更改文件夹',
      L10nKeys.settingsDownloadDirectoryLoading: '正在读取…',
      L10nKeys.settingsDownloadDirectorySaving: '正在保存…',
      L10nKeys.settingsDownloadDirectoryUnavailable: '连接引擎后显示',
      L10nKeys.settingsDownloadDirectoryLoadError: '暂时无法读取默认下载目录，请检查本机引擎。',
      L10nKeys.settingsDownloadDirectorySaveError: '无法保存默认下载目录，请稍后重试。',
      L10nKeys.settingsDownloadDirectoryInvalid: '所选文件夹不存在或当前无法使用，请选择其他本地目录。',
      L10nKeys.settingsDownloadDirectoryOffline: '本机引擎未连接，暂时无法更改默认下载目录。',
      L10nKeys.settingsDownloadDirectoryPickerError: '无法打开文件夹选择器，请稍后重试。',
      L10nKeys.settingsDownloadDirectoryErrorTitle: '默认目录未更改',
      L10nKeys.settingsFileConflictPolicy: '同名文件处理',
      L10nKeys.settingsFileConflictPolicyDescription:
          '新建 HTTP 任务遇到已有文件、临时文件或活动任务占名时，选择生成副本名或停止创建。',
      L10nKeys.settingsFileConflictPolicyRename: '自动重命名',
      L10nKeys.settingsFileConflictPolicyStop: '停止创建',
      L10nKeys.settingsFileConflictPolicyErrorTitle: '重名策略未更改',
      L10nKeys.settingsFileConflictPolicyInvalid: '本机引擎不支持所选重名策略，已保留原设置。',
      L10nKeys.settingsFileConflictPolicyOffline: '本机引擎未连接，暂时无法更改重名策略。',
      L10nKeys.settingsFileConflictPolicySaveError: '无法保存重名策略，请稍后重试。',
      L10nKeys.settingsDownloadCompletionAction: '下载完成后',
      L10nKeys.settingsDownloadCompletionActionDescription:
          '可在任务实时完成后定位文件；启动或刷新时载入的历史完成记录不会触发。',
      L10nKeys.settingsDownloadCompletionActionNone: '无操作',
      L10nKeys.settingsDownloadCompletionActionReveal: '在文件管理器中显示',
      L10nKeys.settingsDownloadsNoteTitle: '文件策略与完成动作分开生效',
      L10nKeys.settingsDownloadsNoteBody:
          '默认目录和重名策略由本机引擎保存，只影响之后创建的 HTTP 任务，且永不覆盖现有文件；BT 多文件任务仍在冲突时停止。完成后动作保存在当前设备，默认无操作；短时间内多项任务完成时只定位最后一项。',
      L10nKeys.settingsScheduler: '速度与调度',
      L10nKeys.settingsSchedulerDescription: '调整下载队列的并发、全局带宽上限和临时故障重试策略。',
      L10nKeys.settingsSchedulerMaxConcurrentTasks: '最大并发任务',
      L10nKeys.settingsSchedulerMaxConcurrentTasksDescription:
          '增加后会立即启动更多排队任务；降低时不会中断已经运行的下载。',
      L10nKeys.settingsSchedulerDownloadRateLimit: '全局下载限速',
      L10nKeys.settingsSchedulerDownloadRateLimitDescription:
          '所有 HTTP 下载连接共享此带宽上限，选择不限速可恢复完整可用带宽。',
      L10nKeys.settingsSchedulerAutomaticRetries: '自动重试次数',
      L10nKeys.settingsSchedulerAutomaticRetriesDescription:
          '临时网络故障按指数退避自动重试；设为 0 后新发生的故障不会自动重试。',
      L10nKeys.settingsSchedulerUnlimited: '不限速',
      L10nKeys.settingsSchedulerRateMenu: '选择全局下载限速',
      L10nKeys.settingsSchedulerDecreaseConcurrency: '减少最大并发任务',
      L10nKeys.settingsSchedulerIncreaseConcurrency: '增加最大并发任务',
      L10nKeys.settingsSchedulerDecreaseRetries: '减少自动重试次数',
      L10nKeys.settingsSchedulerIncreaseRetries: '增加自动重试次数',
      L10nKeys.settingsSchedulerNoteTitle: '调度设置由本机引擎立即执行',
      L10nKeys.settingsSchedulerNoteBody:
          '设置保存成功后立即应用。降低并发不会暂停进行中的任务，只会等待空出槽位后再启动队列；限速会动态作用于当前和之后的 HTTP 下载。',
      L10nKeys.settingsSchedulerErrorTitle: '调度设置未更改',
      L10nKeys.settingsSchedulerInvalid: '调度值超出当前引擎支持的范围。',
      L10nKeys.settingsSchedulerOffline: '本机引擎未连接，暂时无法更改调度设置。',
      L10nKeys.settingsSchedulerSaveError: '无法保存调度设置，请稍后重试。',
      L10nKeys.settingsBT: 'BitTorrent',
      L10nKeys.settingsBTDescription: '管理受限 BT 传输的 Peer 预算，并查看引擎强制关闭的网络能力。',
      L10nKeys.settingsBTPeerBudget: 'Peer 连接上限',
      L10nKeys.settingsBTPeerBudgetDescription:
          '用于新建 BT 任务的每任务连接预算；较低值可减少资源占用。',
      L10nKeys.settingsBTDiscovery: '发现与入站',
      L10nKeys.settingsBTDiscoveryDescription:
          'Tracker · DHT · PEX · WebSeed · IPv6 · 入站连接',
      L10nKeys.settingsBTTransferPolicy: '上传与做种',
      L10nKeys.settingsBTTransferPolicyDescription: '下载期间不上传数据，完成后不进入自动做种。',
      L10nKeys.settingsBTLocked: '安全锁定',
      L10nKeys.settingsBTPolicyNoteTitle: '策略由本机引擎执行',
      L10nKeys.settingsBTPolicyNoteBody:
          'Peer 上限修改后只影响之后新建的 BT 任务。当前只连接用户明确填写的公网 IPv4 Peer；Tracker、DHT、PEX、WebSeed、IPv6、入站、上传和做种在完成独立安全门禁前不能开启。',
      L10nKeys.settingsBTPolicyErrorTitle: 'BT 策略未更改',
      L10nKeys.settingsBTPolicyInvalid: '连接上限超出当前引擎允许的安全范围。',
      L10nKeys.settingsBTPolicyOffline: '本机引擎未连接，暂时无法更改 BT 策略。',
      L10nKeys.settingsBTPolicySaveError: '无法保存 BT 策略，请稍后重试。',
      L10nKeys.settingsReset: '恢复默认',
      L10nKeys.settingsEngine: '本机引擎',
      L10nKeys.settingsEngineDescription: '本机引擎负责下载调度与文件写入，未连接时可使用右侧按钮重新检查。',
      L10nKeys.settingsEngineSectionDescription:
          '查看本机下载服务的连接状态与版本，确认任务列表和实时进度能否正常同步。',
      L10nKeys.settingsEngineNoteTitle: '下载任务由本机引擎处理',
      L10nKeys.settingsEngineNoteBody:
          '本机引擎负责链接解析、队列调度、断点续传和文件写入，界面只读取并显示它的状态。使用刷新按钮只会重新检查连接，不会暂停、重启或修改下载任务。',
      L10nKeys.settingsDiagnostics: '数据与诊断',
      L10nKeys.settingsDiagnosticsDescription: '查看本机数据存储状态，并导出不含任务隐私的诊断包。',
      L10nKeys.settingsDiagnosticsDataDirectory: '引擎数据目录',
      L10nKeys.settingsDiagnosticsDataDirectoryDescription:
          '显示经过缩写的本机存储位置，不暴露当前用户的完整主目录。',
      L10nKeys.settingsDiagnosticsDatabase: '任务数据库',
      L10nKeys.settingsDiagnosticsDatabaseDescription:
          '本机引擎使用的任务与设置数据库，仅显示缩写路径和当前文件大小。',
      L10nKeys.settingsDiagnosticsDatabaseUnavailable: '数据库状态不可用',
      L10nKeys.settingsDiagnosticsLogs: '引擎日志',
      L10nKeys.settingsDiagnosticsLogsDescription:
          '当前版本不在磁盘持久保存运行日志，避免积累不必要的本机信息。',
      L10nKeys.settingsDiagnosticsLogsUnavailable: '未落盘',
      L10nKeys.settingsDiagnosticsTasks: '任务状态摘要',
      L10nKeys.settingsDiagnosticsTasksDescription:
          '只统计任务数量，诊断包不写入链接、文件名、单个任务保存路径和任务标识。',
      L10nKeys.settingsDiagnosticsTasksValue: '@total 个任务 · @active 个活动',
      L10nKeys.settingsDiagnosticsExport: '诊断包',
      L10nKeys.settingsDiagnosticsExportDescription:
          '导出版本、运行时、安全设置摘要、存储状态和任务计数，保存位置由你选择。',
      L10nKeys.settingsDiagnosticsExportAction: '导出诊断包',
      L10nKeys.settingsDiagnosticsExporting: '正在导出…',
      L10nKeys.settingsDiagnosticsLoading: '正在读取…',
      L10nKeys.settingsDiagnosticsUnavailable: '连接引擎后显示',
      L10nKeys.settingsDiagnosticsRefresh: '重新读取',
      L10nKeys.settingsDiagnosticsOffline: '本机引擎未连接，暂时无法读取或导出诊断信息。',
      L10nKeys.settingsDiagnosticsLoadErrorTitle: '诊断信息暂不可用',
      L10nKeys.settingsDiagnosticsLoadError: '本机引擎未能准备诊断摘要，请稍后重试。',
      L10nKeys.settingsDiagnosticsExportErrorTitle: '诊断包未导出',
      L10nKeys.settingsDiagnosticsExportError: '本机引擎未能生成诊断包，请稍后重试。',
      L10nKeys.settingsDiagnosticsSaveError: '诊断包无法保存到所选位置，请选择其他文件夹后重试。',
      L10nKeys.settingsDiagnosticsRevealError: '文件管理器无法定位已保存的诊断包。',
      L10nKeys.settingsDiagnosticsExportSuccessTitle: '诊断包已保存',
      L10nKeys.settingsDiagnosticsExportSuccessBody: '保存位置：@path',
      L10nKeys.settingsDiagnosticsReveal: '显示文件',
      L10nKeys.settingsDiagnosticsPrivacyTitle: '导出内容默认脱敏',
      L10nKeys.settingsDiagnosticsPrivacyBody:
          '诊断包不会包含任务 URL、请求 Header、Cookie、代理凭据、磁力链接、种子元数据、文件名、单个任务保存路径或任务标识。默认目录等必要路径会缩写；当前版本没有可导出的落盘日志。',
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
      L10nKeys.tasksFilterAll: '全部任务',
      L10nKeys.tasksFilterActive: '正在传输',
      L10nKeys.tasksFilterCompleted: '已完成',
      L10nKeys.tasksFilterIssues: '需要处理',
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
      L10nKeys.tasksDeleteSelected: '删除记录',
      L10nKeys.tasksClearCompleted: '清空已完成',
      L10nKeys.tasksClearCompletedTitle: '清空已完成任务？',
      L10nKeys.tasksClearCompletedBody: '只会从任务列表移除 @count 条已完成记录，下载文件会保留。',
      L10nKeys.tasksClearCompletedConfirm: '清空记录',
      L10nKeys.tasksDeleteTitle: '删除任务记录？',
      L10nKeys.tasksDeleteBatchTitle: '删除 @count 个任务？',
      L10nKeys.tasksDeleteBody: '默认只从任务列表移除这条记录，下载文件会保留。',
      L10nKeys.tasksDeleteBatchBody: '默认只从任务列表移除这 @count 条记录，已有下载文件会保留。',
      L10nKeys.tasksDeleteFiles: '同时删除已完成文件',
      L10nKeys.tasksDeleteFilesDescription: '这会永久删除 Downpeed 已完成并保存到本机的普通文件。',
      L10nKeys.tasksDeleteConfirm: '删除记录',
      L10nKeys.tasksDeleteComplete: '已删除 @count 条任务记录。',
      L10nKeys.tasksDeletePartial: '部分任务未能删除（@failed 条）。',
      L10nKeys.tasksDeleteError: '无法删除任务记录，请稍后重试。',
      L10nKeys.tasksBatchComplete: '已更新 @count 个任务。',
      L10nKeys.tasksBatchPartial: '@failed 个任务未能更新，已保留选择。',
      L10nKeys.tasksNoMatchesTitle: '当前视图没有任务',
      L10nKeys.tasksNoMatchesBody: '更换筛选条件，或清除搜索关键词。',
      L10nKeys.tasksEmptyTitle: '还没有下载任务',
      L10nKeys.tasksEmptyBody: '粘贴下载链接或新建任务，下载进度会显示在这里。',
      L10nKeys.tasksEmptyHint: '下载由本机引擎处理',
      L10nKeys.tasksPaste: '粘贴链接',
      L10nKeys.tasksComingSoon: '新建下载支持 HTTP/HTTPS、批量链接和计划启动。',
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
      L10nKeys.createUrlHint: '粘贴链接，每行一个，最多 100 个',
      L10nKeys.createResolve: '解析链接',
      L10nKeys.createResolving: '正在检查远端文件',
      L10nKeys.createResolvingBody: '读取文件名、大小与断点续传能力。',
      L10nKeys.createIdleHint: '链接只会发送给本机 Downpeed 引擎进行检查。',
      L10nKeys.createAdvanced: '高级请求选项',
      L10nKeys.createAdvancedBody: '高级 Header、Cookie 与代理选项将在后续版本开放。',
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
      L10nKeys.createNextBody: '选择保存位置和开始时间后，任务会加入本机引擎队列。',
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
      L10nKeys.createSchedule: '开始时间',
      L10nKeys.createScheduleBody: '可选择立即开始，或把任务安排到稍后自动加入传输。',
      L10nKeys.createScheduleNow: '立即开始',
      L10nKeys.createScheduleChoose: '选择时间',
      L10nKeys.createScheduleClear: '清除计划',
      L10nKeys.createScheduleInvalid: '请选择未来的开始时间。',
      L10nKeys.createDirectoryRequired: '开始下载前，请先选择保存文件夹。',
      L10nKeys.createDirectoryError: '无法使用这个文件夹，请重新选择一个本机目录。',
      L10nKeys.createDestinationExists: '同名文件已经存在，请更换保存位置。',
      L10nKeys.createStartDownload: '开始下载',
      L10nKeys.createCreating: '正在创建下载任务',
      L10nKeys.createCreatingBody: '本机引擎正在把任务加入传输队列。',
      L10nKeys.createTaskError: '无法创建下载任务，请检查引擎状态后重试。',
      L10nKeys.createTaskActionError: '暂时无法更新任务状态，请稍后重试。',
      L10nKeys.createCancelError: '任务暂时无法取消，请稍后重试。',
      L10nKeys.createEventsInterrupted: '实时进度连接已中断，任务仍会在引擎中继续。',
      L10nKeys.createBTChooseTorrent: '选择 Torrent 文件',
      L10nKeys.createBTPickerHint:
          '支持 Magnet 链接或不超过 8 MiB 的 .torrent 文件；解析过程不会连接 Peer。',
      L10nKeys.createBTResolvedTitle: 'Torrent 元数据已验证',
      L10nKeys.createBTResolvedBody: '文件路径与声明大小已由本机 Go 引擎检查。',
      L10nKeys.createBTMagnetTitle: 'Magnet 身份已验证',
      L10nKeys.createBTMagnetBody: '纯解析阶段不会连接 Tracker、DHT 或 Peer，因此暂时没有文件列表。',
      L10nKeys.createBTInfoHash: 'InfoHash',
      L10nKeys.createBTTrackers: 'Tracker',
      L10nKeys.createBTPrivacy: '隐私标记',
      L10nKeys.createBTPrivate: '私有 Torrent',
      L10nKeys.createBTPublic: '公开 Torrent',
      L10nKeys.createBTFiles: '文件选择',
      L10nKeys.createBTSelectAll: '选择全部文件',
      L10nKeys.createBTSelectedSummary: '已选择 @selected / @total 个文件 · @size',
      L10nKeys.createBTParsingOnly: '当前阶段只完成安全解析与文件选择，不会开始 BT 传输或写入下载目录。',
      L10nKeys.createBTMagnetParsingOnly: 'Magnet 当前只验证身份，不获取远端元数据，也不能创建传输任务。',
      L10nKeys.createBTRestrictedTransfer:
          '受限 BT 模式只连接你明确填写的公网 IPv4 Peer；Tracker、DHT、PEX、WebSeed、入站连接、上传和做种均保持关闭。',
      L10nKeys.createBTPeers: '显式 Peer',
      L10nKeys.createBTPeersBody:
          '每行输入一个公网 IPv4:端口。Downpeed 不会使用 Torrent 内的 Tracker 自动发现 Peer。',
      L10nKeys.createBTPeersHint: '例如：8.8.8.8:6881',
      L10nKeys.createBTSecurityNotice:
          'Peer 会看到你的公网 IP。只下载你有权获取和保存的内容；首版不会上传任何数据。',
      L10nKeys.createBTStart: '开始受限 BT 下载',
      L10nKeys.createBTFilesRequired: '请至少选择一个 Torrent 文件。',
      L10nKeys.createBTPeerRequired: '至少填写一个公网 IPv4 Peer 才能开始下载。',
      L10nKeys.createBTPeerInvalid: 'Peer 必须使用 IPv4:端口格式，端口范围为 1–65535。',
      L10nKeys.createBTPeerRestricted: 'Loopback、私网、链路本地和保留网段不能作为 BT Peer。',
      L10nKeys.createBTPeerLimit: '单个任务最多填写 80 个 Peer。',
      L10nKeys.createBTUnavailable: '当前引擎未启用受限 BT 传输，请更新或重启引擎。',
      L10nKeys.createBTInvalidMagnet: 'Magnet 链接缺少有效 InfoHash，或参数不符合安全限制。',
      L10nKeys.createBTMetadataTooLarge: 'Torrent 文件不能超过 8 MiB。',
      L10nKeys.createBTPathUnsafe: 'Torrent 中包含不安全、冲突或可能越过保存目录的文件路径。',
      L10nKeys.createBTFileLimit: 'Torrent 文件数量超过 10,000 个，无法安全显示。',
      L10nKeys.createBTSizeLimit: 'Torrent 声明的文件体积超过当前安全上限。',
      L10nKeys.createBTTrackerInvalid: 'Torrent 中包含不支持或格式不安全的 Tracker 地址。',
      L10nKeys.createBTTorrentError: '无法解析这个 Torrent 文件，请确认文件完整且格式受支持。',
      L10nKeys.createBTMagnetError: '无法解析这个 Magnet 链接。',
      L10nKeys.createBTMixedInput: 'Magnet 需要单独解析，不能和 HTTP 链接批量混合。',
      L10nKeys.taskQueued: '等待传输',
      L10nKeys.taskQueuedBody: '任务已进入队列，会在并发槽位可用时自动开始。',
      L10nKeys.taskScheduledBody: '任务已安排在 @time 开始，届时会自动加入传输。',
      L10nKeys.taskScheduledLabel: '计划 @time 开始',
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
      L10nKeys.taskConnections: 'Peer 连接',
      L10nKeys.taskProtocol: '协议',
      L10nKeys.taskProtocolBT: '受限 BitTorrent',
      L10nKeys.taskBTDiagnostics: '连接诊断',
      L10nKeys.taskBTDiagnosticsBody: '按需查看实时 Peer、流量与受限网络策略。',
      L10nKeys.taskBTLive: '实时',
      L10nKeys.taskBTStopped: '未运行',
      L10nKeys.taskBTConfigured: '已配置',
      L10nKeys.taskBTPeerLimit: '连接上限',
      L10nKeys.taskBTConnected: '已连接',
      L10nKeys.taskBTPending: '待连接',
      L10nKeys.taskBTHalfOpen: '握手中',
      L10nKeys.taskBTUsefulTraffic: '有效接收',
      L10nKeys.taskBTUploadTraffic: '已上传',
      L10nKeys.taskBTPeers: 'Peer',
      L10nKeys.taskBTNoPeers: '当前没有已建立的 Peer 连接。',
      L10nKeys.taskBTPeerPrivacy: 'Peer 地址已脱敏，只保留网络前缀和端口。',
      L10nKeys.taskBTPolicy: '网络策略',
      L10nKeys.taskBTPolicyRestricted:
          'Tracker · DHT · PEX · WebSeed · 入站 · IPv6 · 上传 · 做种',
      L10nKeys.taskBTDisabled: '全部关闭',
      L10nKeys.taskBTUnexpectedEnabled: '检测到已启用能力',
      L10nKeys.taskBTExplicitOnly: '仅显式公网 IPv4 Peer',
      L10nKeys.taskBTDiagnosticsError: '无法读取连接诊断，请稍后重试。',
      L10nKeys.taskBTRefresh: '刷新诊断',
      L10nKeys.taskDestination: '保存到',
      L10nKeys.taskCancel: '取消下载',
      L10nKeys.taskDelete: '删除任务记录',
      L10nKeys.taskCanceling: '正在取消',
      L10nKeys.taskPause: '暂停',
      L10nKeys.taskResume: '继续',
      L10nKeys.taskRetry: '重试',
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
      L10nKeys.navOverview: 'Overview',
      L10nKeys.navTasks: 'Downloads',
      L10nKeys.navNetwork: 'Network',
      L10nKeys.navAll: 'All transfers',
      L10nKeys.navActive: 'Active',
      L10nKeys.navCompleted: 'Completed',
      L10nKeys.navIssues: 'Needs attention',
      L10nKeys.navSettings: 'Settings',
      L10nKeys.sidebarCollapse: 'Collapse sidebar',
      L10nKeys.sidebarExpand: 'Expand sidebar',
      L10nKeys.sidebarThemeToLight: 'Switch to light mode',
      L10nKeys.sidebarThemeToDark: 'Switch to dark mode',
      L10nKeys.overviewTitle: 'Overview',
      L10nKeys.overviewSubtitle:
          'Review current transfers, the queue, and recent tasks.',
      L10nKeys.overviewCurrentSpeed: 'Current download speed',
      L10nKeys.overviewActive: 'Transferring',
      L10nKeys.overviewQueued: 'Queued & paused',
      L10nKeys.overviewCompleted: 'Completed',
      L10nKeys.overviewIssues: 'Needs attention',
      L10nKeys.overviewCurrentTransfers: 'Current transfers',
      L10nKeys.overviewCurrentTransfersSubtitle:
          'Downloads, retries, queued tasks, and paused work appear first.',
      L10nKeys.overviewRecent: 'Recent tasks',
      L10nKeys.overviewRecentSubtitle: 'Ordered by the latest update.',
      L10nKeys.overviewViewAll: 'View all downloads',
      L10nKeys.overviewNewDownload: 'New download',
      L10nKeys.overviewPasteLink: 'Paste link',
      L10nKeys.overviewRefresh: 'Refresh tasks',
      L10nKeys.overviewActions: 'Overview actions',
      L10nKeys.overviewNoActiveTitle: 'No transfer is active',
      L10nKeys.overviewNoActiveBody:
          'The queue is idle. New tasks will appear here.',
      L10nKeys.overviewNoRecentTitle: 'No recent tasks yet',
      L10nKeys.overviewNoRecentBody:
          'Completed and updated downloads will be easy to revisit here.',
      L10nKeys.overviewActivity: 'Activity',
      L10nKeys.overviewActivitySubtitle:
          'Task updates across the last 13 weeks.',
      L10nKeys.overviewActivityLess: 'Less',
      L10nKeys.overviewActivityMore: 'More',
      L10nKeys.overviewActivityEmpty:
          'Completed or updated tasks will appear here.',
      L10nKeys.overviewActivityMonday: 'Mon',
      L10nKeys.overviewActivityWednesday: 'Wed',
      L10nKeys.overviewActivityFriday: 'Fri',
      L10nKeys.networkTitle: 'Network',
      L10nKeys.networkSubtitle:
          'Review the local engine, download scheduling, and restricted BitTorrent boundary.',
      L10nKeys.networkRefresh: 'Refresh engine',
      L10nKeys.networkOpenSettings: 'Open settings',
      L10nKeys.networkEngine: 'Local engine',
      L10nKeys.networkEngineSubtitle:
          'The interface reads tasks and live progress through the local API.',
      L10nKeys.networkEngineName: 'Engine',
      L10nKeys.networkEngineVersion: 'Version',
      L10nKeys.networkApi: 'API',
      L10nKeys.networkRuntime: 'Runtime',
      L10nKeys.networkPlatform: 'Platform',
      L10nKeys.networkScheduler: 'Speed & scheduling',
      L10nKeys.networkSchedulerSubtitle:
          'Concurrency, bandwidth, and failure retry policies enforced by the local engine.',
      L10nKeys.networkMaxConcurrentTasks: 'Maximum concurrent tasks',
      L10nKeys.networkConcurrentTasksValue: '@count tasks',
      L10nKeys.networkDownloadRateLimit: 'Global download limit',
      L10nKeys.networkAutomaticRetries: 'Automatic retries',
      L10nKeys.networkRetriesValue: '@count retries',
      L10nKeys.networkUnlimited: 'Unlimited',
      L10nKeys.networkDownloads: 'Download boundary',
      L10nKeys.networkDownloadsSubtitle:
          'Default save location and the restricted BT peer budget.',
      L10nKeys.networkDefaultDirectory: 'Default download folder',
      L10nKeys.networkPeerBudget: 'Peer budget per task',
      L10nKeys.networkPeerBudgetValue: '@count connections',
      L10nKeys.networkPolicy: 'Restricted network policy',
      L10nKeys.networkPolicySubtitle:
          'The local engine enforces these capabilities until each security gate is complete.',
      L10nKeys.networkPolicyRestricted: 'Restricted policy intact',
      L10nKeys.networkPolicyUnexpected: 'Unexpected capability detected',
      L10nKeys.networkExplicitPeers: 'Explicit public IPv4 peers only',
      L10nKeys.networkTrackers: 'Trackers',
      L10nKeys.networkDht: 'DHT',
      L10nKeys.networkPex: 'PEX',
      L10nKeys.networkWebSeeds: 'WebSeed',
      L10nKeys.networkIpv6: 'IPv6',
      L10nKeys.networkInbound: 'Inbound connections',
      L10nKeys.networkUpload: 'Upload',
      L10nKeys.networkSeeding: 'Seeding',
      L10nKeys.networkEnabled: 'Enabled',
      L10nKeys.networkDisabled: 'Disabled',
      L10nKeys.networkLoading: 'Loading engine information…',
      L10nKeys.networkUnavailable:
          'Connect the local engine to view network information.',
      L10nKeys.settingsTitle: 'Settings',
      L10nKeys.settingsSubtitle: 'Manage local preferences.',
      L10nKeys.settingsBackToTasks: 'Back to transfers',
      L10nKeys.settingsBackToMenu: 'Back to settings',
      L10nKeys.settingsNavigationPreferences: 'Preferences',
      L10nKeys.settingsNavigationSystem: 'System',
      L10nKeys.settingsNavigationDownloads: 'Downloads & network',
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
          'Show the full Overview, Downloads, and Network menu when the window has enough room.',
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
      L10nKeys.settingsCloseToTray: 'Keep running in the tray',
      L10nKeys.settingsCloseToTrayDescription:
          'Keep downloads running after the main window closes. Restore or fully quit from the system tray.',
      L10nKeys.settingsLaunchAtLogin: 'Launch Downpeed at login',
      L10nKeys.settingsLaunchAtLoginDescription:
          'Managed by the operating system. Manual launches always show the window.',
      L10nKeys.settingsStartHiddenOnLogin: 'Start quietly at login',
      L10nKeys.settingsStartHiddenOnLoginDescription:
          'Hide the window only when launched by the system login item. If the tray is unavailable, the window is shown.',
      L10nKeys.settingsStartupUnavailableTitle:
          'Login launch is unavailable on this system',
      L10nKeys.settingsStartupUnavailableBody:
          'macOS 13 or later is required. Windows and Linux need a writable per-user login item. Manual launch is unaffected.',
      L10nKeys.settingsStartupErrorTitle:
          'The login launch setting was not changed',
      L10nKeys.settingsStartupReadError:
          'The current system login item could not be read. Try again later.',
      L10nKeys.settingsStartupUpdateError:
          'The system could not update the login item. The actual system state has been restored.',
      L10nKeys.settingsStartupVerificationError:
          'The system reported a different login item state. The actual state is shown.',
      L10nKeys.settingsNotificationsNoteTitle:
          'Notification permission is managed by your system',
      L10nKeys.settingsNotificationsNoteBody:
          'Turning this off immediately stops new Downpeed completion notifications without affecting downloads. If permission was denied in system settings, allow it there before notifications can appear.',
      L10nKeys.settingsDownloads: 'Downloads & files',
      L10nKeys.settingsDownloadsDescription:
          'Choose where new tasks save, how name conflicts are handled, and what this device does on completion.',
      L10nKeys.settingsDownloadDirectory: 'Default download folder',
      L10nKeys.settingsDownloadDirectoryDescription:
          'New HTTP downloads use this folder automatically. You can still override it for an individual task.',
      L10nKeys.settingsDownloadDirectoryChange: 'Change folder',
      L10nKeys.settingsDownloadDirectoryLoading: 'Loading…',
      L10nKeys.settingsDownloadDirectorySaving: 'Saving…',
      L10nKeys.settingsDownloadDirectoryUnavailable:
          'Connect the engine to view',
      L10nKeys.settingsDownloadDirectoryLoadError:
          'The default download folder could not be read. Check the local engine.',
      L10nKeys.settingsDownloadDirectorySaveError:
          'The default download folder could not be saved. Try again.',
      L10nKeys.settingsDownloadDirectoryInvalid:
          'This folder does not exist or cannot be used. Choose another local folder.',
      L10nKeys.settingsDownloadDirectoryOffline:
          'The local engine is offline, so the default download folder cannot be changed.',
      L10nKeys.settingsDownloadDirectoryPickerError:
          'The folder picker could not be opened. Try again.',
      L10nKeys.settingsDownloadDirectoryErrorTitle:
          'Default folder not changed',
      L10nKeys.settingsFileConflictPolicy: 'Existing file names',
      L10nKeys.settingsFileConflictPolicyDescription:
          'When a new HTTP task finds an existing file, partial file, or active task with the same name, create a copy name or stop.',
      L10nKeys.settingsFileConflictPolicyRename: 'Auto rename',
      L10nKeys.settingsFileConflictPolicyStop: 'Stop',
      L10nKeys.settingsFileConflictPolicyErrorTitle:
          'File conflict setting not changed',
      L10nKeys.settingsFileConflictPolicyInvalid:
          'The local engine does not support this file conflict policy. The previous setting was kept.',
      L10nKeys.settingsFileConflictPolicyOffline:
          'The local engine is offline, so file conflict handling cannot be changed.',
      L10nKeys.settingsFileConflictPolicySaveError:
          'File conflict handling could not be saved. Try again.',
      L10nKeys.settingsDownloadCompletionAction: 'After download completes',
      L10nKeys.settingsDownloadCompletionActionDescription:
          'Optionally reveal files after a live completion. Historical completed records loaded at startup or refresh never trigger it.',
      L10nKeys.settingsDownloadCompletionActionNone: 'Do nothing',
      L10nKeys.settingsDownloadCompletionActionReveal: 'Reveal in file manager',
      L10nKeys.settingsDownloadsNoteTitle:
          'File rules and completion actions apply separately',
      L10nKeys.settingsDownloadsNoteBody:
          'The local engine stores the default folder and conflict policy for future HTTP tasks only, and never overwrites existing files. Multi-file BT tasks still stop on conflicts. The completion action is stored on this device and defaults to doing nothing; a burst of completions reveals only the last file.',
      L10nKeys.settingsScheduler: 'Speed & scheduling',
      L10nKeys.settingsSchedulerDescription:
          'Tune queue concurrency, the global bandwidth ceiling, and retries for temporary failures.',
      L10nKeys.settingsSchedulerMaxConcurrentTasks: 'Maximum concurrent tasks',
      L10nKeys.settingsSchedulerMaxConcurrentTasksDescription:
          'Raising this starts more queued tasks immediately. Lowering it never interrupts active downloads.',
      L10nKeys.settingsSchedulerDownloadRateLimit: 'Global download limit',
      L10nKeys.settingsSchedulerDownloadRateLimitDescription:
          'All HTTP download connections share this ceiling. Choose Unlimited to restore all available bandwidth.',
      L10nKeys.settingsSchedulerAutomaticRetries: 'Automatic retries',
      L10nKeys.settingsSchedulerAutomaticRetriesDescription:
          'Temporary network failures retry with exponential backoff. Set this to 0 to disable new automatic retries.',
      L10nKeys.settingsSchedulerUnlimited: 'Unlimited',
      L10nKeys.settingsSchedulerRateMenu: 'Choose global download limit',
      L10nKeys.settingsSchedulerDecreaseConcurrency:
          'Decrease maximum concurrent tasks',
      L10nKeys.settingsSchedulerIncreaseConcurrency:
          'Increase maximum concurrent tasks',
      L10nKeys.settingsSchedulerDecreaseRetries: 'Decrease automatic retries',
      L10nKeys.settingsSchedulerIncreaseRetries: 'Increase automatic retries',
      L10nKeys.settingsSchedulerNoteTitle:
          'The local engine applies scheduling changes immediately',
      L10nKeys.settingsSchedulerNoteBody:
          'Changes take effect after the engine saves them. Lower concurrency does not pause active tasks; the queue waits for free slots. The rate limit updates current and future HTTP downloads dynamically.',
      L10nKeys.settingsSchedulerErrorTitle: 'Scheduling settings not changed',
      L10nKeys.settingsSchedulerInvalid:
          'A scheduling value is outside the range supported by this engine.',
      L10nKeys.settingsSchedulerOffline:
          'The local engine is offline, so scheduling settings cannot be changed.',
      L10nKeys.settingsSchedulerSaveError:
          'Scheduling settings could not be saved. Try again.',
      L10nKeys.settingsBT: 'BitTorrent',
      L10nKeys.settingsBTDescription:
          'Manage the peer budget for restricted BT transfers and review capabilities locked off by the engine.',
      L10nKeys.settingsBTPeerBudget: 'Peer connection limit',
      L10nKeys.settingsBTPeerBudgetDescription:
          'Per-task connection budget for newly created BT tasks. Lower values reduce resource use.',
      L10nKeys.settingsBTDiscovery: 'Discovery & inbound',
      L10nKeys.settingsBTDiscoveryDescription:
          'Tracker · DHT · PEX · WebSeed · IPv6 · inbound connections',
      L10nKeys.settingsBTTransferPolicy: 'Upload & seeding',
      L10nKeys.settingsBTTransferPolicyDescription:
          'No data upload while downloading and no automatic seeding after completion.',
      L10nKeys.settingsBTLocked: 'Security locked',
      L10nKeys.settingsBTPolicyNoteTitle:
          'The policy is enforced by the local engine',
      L10nKeys.settingsBTPolicyNoteBody:
          'Peer-limit changes apply only to newly created BT tasks. Downpeed currently connects only to explicit public IPv4 peers; Tracker, DHT, PEX, WebSeed, IPv6, inbound, upload, and seeding cannot be enabled until their independent security gates are complete.',
      L10nKeys.settingsBTPolicyErrorTitle: 'BT policy not changed',
      L10nKeys.settingsBTPolicyInvalid:
          'The connection limit is outside the engine’s current safe range.',
      L10nKeys.settingsBTPolicyOffline:
          'The local engine is offline, so the BT policy cannot be changed.',
      L10nKeys.settingsBTPolicySaveError:
          'The BT policy could not be saved. Try again.',
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
      L10nKeys.settingsDiagnostics: 'Data & diagnostics',
      L10nKeys.settingsDiagnosticsDescription:
          'Review local storage health and export a diagnostic bundle without task-level private data.',
      L10nKeys.settingsDiagnosticsDataDirectory: 'Engine data folder',
      L10nKeys.settingsDiagnosticsDataDirectoryDescription:
          'Shows a shortened local storage location without exposing the full user home path.',
      L10nKeys.settingsDiagnosticsDatabase: 'Task database',
      L10nKeys.settingsDiagnosticsDatabaseDescription:
          'The engine task and settings database, shown only as a shortened path and current file size.',
      L10nKeys.settingsDiagnosticsDatabaseUnavailable:
          'Database status unavailable',
      L10nKeys.settingsDiagnosticsLogs: 'Engine logs',
      L10nKeys.settingsDiagnosticsLogsDescription:
          'This build does not persist runtime logs to disk, avoiding unnecessary local data retention.',
      L10nKeys.settingsDiagnosticsLogsUnavailable: 'Not stored',
      L10nKeys.settingsDiagnosticsTasks: 'Task status summary',
      L10nKeys.settingsDiagnosticsTasksDescription:
          'Counts tasks only. Links, file names, per-task save paths, and task identifiers are not written into the bundle.',
      L10nKeys.settingsDiagnosticsTasksValue: '@total tasks · @active active',
      L10nKeys.settingsDiagnosticsExport: 'Diagnostic bundle',
      L10nKeys.settingsDiagnosticsExportDescription:
          'Export versions, runtime details, safe settings, storage health, and task counts to a location you choose.',
      L10nKeys.settingsDiagnosticsExportAction: 'Export bundle',
      L10nKeys.settingsDiagnosticsExporting: 'Exporting…',
      L10nKeys.settingsDiagnosticsLoading: 'Loading…',
      L10nKeys.settingsDiagnosticsUnavailable: 'Connect the engine to view',
      L10nKeys.settingsDiagnosticsRefresh: 'Reload',
      L10nKeys.settingsDiagnosticsOffline:
          'The local engine is offline, so diagnostic information cannot be read or exported.',
      L10nKeys.settingsDiagnosticsLoadErrorTitle:
          'Diagnostic information is unavailable',
      L10nKeys.settingsDiagnosticsLoadError:
          'The local engine could not prepare its diagnostic summary. Try again later.',
      L10nKeys.settingsDiagnosticsExportErrorTitle:
          'Diagnostic bundle not exported',
      L10nKeys.settingsDiagnosticsExportError:
          'The local engine could not generate a diagnostic bundle. Try again later.',
      L10nKeys.settingsDiagnosticsSaveError:
          'The bundle could not be saved to that location. Choose another folder and try again.',
      L10nKeys.settingsDiagnosticsRevealError:
          'The file manager could not reveal the saved diagnostic bundle.',
      L10nKeys.settingsDiagnosticsExportSuccessTitle: 'Diagnostic bundle saved',
      L10nKeys.settingsDiagnosticsExportSuccessBody: 'Saved to @path',
      L10nKeys.settingsDiagnosticsReveal: 'Show file',
      L10nKeys.settingsDiagnosticsPrivacyTitle:
          'Exported information is redacted by default',
      L10nKeys.settingsDiagnosticsPrivacyBody:
          'The bundle excludes task URLs, request headers, cookies, proxy credentials, magnet links, torrent metadata, file names, per-task save paths, and task identifiers. Necessary paths such as the default folder are shortened, and this build has no persisted logs to export.',
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
      L10nKeys.tasksFilterAll: 'All transfers',
      L10nKeys.tasksFilterActive: 'Active',
      L10nKeys.tasksFilterCompleted: 'Completed',
      L10nKeys.tasksFilterIssues: 'Needs attention',
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
      L10nKeys.tasksDeleteSelected: 'Delete records',
      L10nKeys.tasksClearCompleted: 'Clear completed',
      L10nKeys.tasksClearCompletedTitle: 'Clear completed tasks?',
      L10nKeys.tasksClearCompletedBody:
          'This removes @count completed records from the list. Downloaded files are kept.',
      L10nKeys.tasksClearCompletedConfirm: 'Clear records',
      L10nKeys.tasksDeleteTitle: 'Delete task record?',
      L10nKeys.tasksDeleteBatchTitle: 'Delete @count tasks?',
      L10nKeys.tasksDeleteBody:
          'By default, only this record is removed from the list. The downloaded file is kept.',
      L10nKeys.tasksDeleteBatchBody:
          'By default, only these @count records are removed from the list. Downloaded files are kept.',
      L10nKeys.tasksDeleteFiles: 'Also delete completed files',
      L10nKeys.tasksDeleteFilesDescription:
          'This permanently deletes regular files that Downpeed completed and saved locally.',
      L10nKeys.tasksDeleteConfirm: 'Delete records',
      L10nKeys.tasksDeleteComplete: 'Deleted @count task records.',
      L10nKeys.tasksDeletePartial: '@failed tasks could not be deleted.',
      L10nKeys.tasksDeleteError:
          'Task records could not be deleted. Try again.',
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
      L10nKeys.tasksComingSoon:
          'New downloads support HTTP/HTTPS, batches, and scheduled starts.',
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
      L10nKeys.createUrlHint: 'Paste links, one per line, up to 100',
      L10nKeys.createResolve: 'Inspect link',
      L10nKeys.createResolving: 'Inspecting the remote file',
      L10nKeys.createResolvingBody:
          'Reading its name, size, and resume capability.',
      L10nKeys.createIdleHint:
          'The link is inspected only by your local Downpeed engine.',
      L10nKeys.createAdvanced: 'Advanced request options',
      L10nKeys.createAdvancedBody:
          'Advanced headers, cookies, and proxy options will arrive in a later release.',
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
          'Choose a save location and start time, then the task enters the local engine queue.',
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
      L10nKeys.createSchedule: 'Start time',
      L10nKeys.createScheduleBody:
          'Start immediately or schedule the task for a later time.',
      L10nKeys.createScheduleNow: 'Start immediately',
      L10nKeys.createScheduleChoose: 'Choose time',
      L10nKeys.createScheduleClear: 'Clear schedule',
      L10nKeys.createScheduleInvalid: 'Choose a future start time.',
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
      L10nKeys.createTaskActionError:
          'The task state could not be updated. Try again shortly.',
      L10nKeys.createCancelError:
          'The task cannot be canceled right now. Try again shortly.',
      L10nKeys.createEventsInterrupted:
          'Live progress was interrupted. The task continues in the engine.',
      L10nKeys.createBTChooseTorrent: 'Choose Torrent file',
      L10nKeys.createBTPickerHint:
          'Use a Magnet link or a .torrent file up to 8 MiB. Parsing does not contact peers.',
      L10nKeys.createBTResolvedTitle: 'Torrent metadata verified',
      L10nKeys.createBTResolvedBody:
          'File paths and declared sizes were checked by the local Go engine.',
      L10nKeys.createBTMagnetTitle: 'Magnet identity verified',
      L10nKeys.createBTMagnetBody:
          'This parsing stage does not contact trackers, DHT, or peers, so the file list is not available yet.',
      L10nKeys.createBTInfoHash: 'InfoHash',
      L10nKeys.createBTTrackers: 'Trackers',
      L10nKeys.createBTPrivacy: 'Privacy flag',
      L10nKeys.createBTPrivate: 'Private Torrent',
      L10nKeys.createBTPublic: 'Public Torrent',
      L10nKeys.createBTFiles: 'File selection',
      L10nKeys.createBTSelectAll: 'Select all files',
      L10nKeys.createBTSelectedSummary:
          '@selected of @total files selected · @size',
      L10nKeys.createBTParsingOnly:
          'This stage only performs safe parsing and file selection. It does not start BT transfer or write to the download folder.',
      L10nKeys.createBTMagnetParsingOnly:
          'Magnet currently verifies identity only. It does not fetch remote metadata or create a transfer task.',
      L10nKeys.createBTRestrictedTransfer:
          'Restricted BT only contacts public IPv4 peers you enter. Trackers, DHT, PEX, web seeds, incoming peers, uploads, and seeding remain disabled.',
      L10nKeys.createBTPeers: 'Explicit peers',
      L10nKeys.createBTPeersBody:
          'Enter one public IPv4:port per line. Downpeed does not use Torrent trackers to discover peers.',
      L10nKeys.createBTPeersHint: 'Example: 8.8.8.8:6881',
      L10nKeys.createBTSecurityNotice:
          'Peers can see your public IP. Only download content you are allowed to obtain and save; this release never uploads data.',
      L10nKeys.createBTStart: 'Start restricted BT download',
      L10nKeys.createBTFilesRequired: 'Select at least one Torrent file.',
      L10nKeys.createBTPeerRequired:
          'Enter at least one public IPv4 peer before starting.',
      L10nKeys.createBTPeerInvalid:
          'Peers must use IPv4:port format with a port from 1 to 65535.',
      L10nKeys.createBTPeerRestricted:
          'Loopback, private, link-local, and reserved networks cannot be BT peers.',
      L10nKeys.createBTPeerLimit: 'A task can use up to 80 explicit peers.',
      L10nKeys.createBTUnavailable:
          'Restricted BT is not enabled in this engine. Update or restart it.',
      L10nKeys.createBTInvalidMagnet:
          'The Magnet link has no valid InfoHash or exceeds safe parameter limits.',
      L10nKeys.createBTMetadataTooLarge:
          'Torrent metadata cannot exceed 8 MiB.',
      L10nKeys.createBTPathUnsafe:
          'The Torrent contains an unsafe, conflicting, or escaping file path.',
      L10nKeys.createBTFileLimit:
          'The Torrent has more than 10,000 files and cannot be displayed safely.',
      L10nKeys.createBTSizeLimit:
          'The Torrent declares more data than the current safety limit.',
      L10nKeys.createBTTrackerInvalid:
          'The Torrent contains an unsupported or unsafe Tracker address.',
      L10nKeys.createBTTorrentError:
          'This Torrent file could not be parsed. Check that it is complete and supported.',
      L10nKeys.createBTMagnetError: 'This Magnet link could not be parsed.',
      L10nKeys.createBTMixedInput:
          'Inspect Magnet links separately from HTTP batch links.',
      L10nKeys.taskQueued: 'Waiting to transfer',
      L10nKeys.taskQueuedBody:
          'The task is queued and starts when a concurrency slot is available.',
      L10nKeys.taskScheduledBody:
          'Scheduled to start at @time, then it will join the transfer queue.',
      L10nKeys.taskScheduledLabel: 'Scheduled @time',
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
      L10nKeys.taskConnections: 'Peer connections',
      L10nKeys.taskProtocol: 'Protocol',
      L10nKeys.taskProtocolBT: 'Restricted BitTorrent',
      L10nKeys.taskBTDiagnostics: 'Connection diagnostics',
      L10nKeys.taskBTDiagnosticsBody:
          'Inspect live peers, traffic, and restricted network policy on demand.',
      L10nKeys.taskBTLive: 'Live',
      L10nKeys.taskBTStopped: 'Not running',
      L10nKeys.taskBTConfigured: 'Configured',
      L10nKeys.taskBTPeerLimit: 'Peer limit',
      L10nKeys.taskBTConnected: 'Connected',
      L10nKeys.taskBTPending: 'Pending',
      L10nKeys.taskBTHalfOpen: 'Handshaking',
      L10nKeys.taskBTUsefulTraffic: 'Useful received',
      L10nKeys.taskBTUploadTraffic: 'Uploaded',
      L10nKeys.taskBTPeers: 'Peers',
      L10nKeys.taskBTNoPeers: 'No peer connection is currently established.',
      L10nKeys.taskBTPeerPrivacy:
          'Peer addresses are masked to a network prefix and port.',
      L10nKeys.taskBTPolicy: 'Network policy',
      L10nKeys.taskBTPolicyRestricted:
          'Tracker · DHT · PEX · WebSeed · inbound · IPv6 · upload · seeding',
      L10nKeys.taskBTDisabled: 'All disabled',
      L10nKeys.taskBTUnexpectedEnabled: 'Enabled capability detected',
      L10nKeys.taskBTExplicitOnly: 'Explicit public IPv4 peers only',
      L10nKeys.taskBTDiagnosticsError:
          'Connection diagnostics could not be loaded. Try again.',
      L10nKeys.taskBTRefresh: 'Refresh diagnostics',
      L10nKeys.taskDestination: 'Save to',
      L10nKeys.taskCancel: 'Cancel download',
      L10nKeys.taskDelete: 'Delete task record',
      L10nKeys.taskCanceling: 'Canceling',
      L10nKeys.taskPause: 'Pause',
      L10nKeys.taskResume: 'Resume',
      L10nKeys.taskRetry: 'Retry',
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
