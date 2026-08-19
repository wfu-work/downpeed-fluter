# Downpeed 桌面输入契约

本文档定义 M4 的应用内固定快捷键与桌面 URL Scheme 边界。它不包含可自定义快捷键、OS 全局热键、浏览器扩展或自动接管普通 HTTP/HTTPS 链接。

## 应用命令

| 命令 | macOS | Windows / Linux | 行为 |
| --- | --- | --- | --- |
| 新建下载 | `⌘ N` | `Ctrl N` | 切换到下载任务并打开空白新建弹窗 |
| 搜索任务 | `⌘ F` | `Ctrl F` | 切换到下载任务，聚焦搜索框并选中已有关键词 |
| 打开设置 | `⌘ ,` | `Ctrl ,` | 打开设置主界面 |
| 刷新当前内容 | `⌘ R` | `Ctrl R` | 按当前页面刷新任务、引擎或设置状态 |

快捷键绑定在 Flutter 应用根节点，概览、下载任务、网络和设置共享同一命令服务。弹窗已打开时不会叠加新的全局命令；启动期间收到的外部命令会等待导航首帧就绪后按顺序执行。

## URL Scheme

唯一受支持的格式：

```text
downpeed://download?url=<percent-encoded-http-or-https-url>
```

示例：

```text
downpeed://download?url=https%3A%2F%2Fexample.com%2Frelease.zip
```

校验规则：

1. 完整 URI 的 UTF-8 长度不超过 8192 字节。
2. scheme 必须是 `downpeed`，命令必须是 `download`，不能包含端口、路径、userinfo 或 fragment。
3. query 必须只有一个 `url` 参数；重复参数和未知参数都拒绝。
4. 解码后的目标必须是带主机的 `http` 或 `https` URL，并拒绝 userinfo 与控制字符。
5. 原生层负责系统协议注册、单实例投递和窗口恢复；Dart 层始终执行最终校验。
6. 接收成功后只预填新建下载弹窗。用户仍需主动解析并确认创建任务。
7. 失败只返回固定错误类别，不记录或回显目标 URL、query、凭据或下载路径。

## 平台接入

- macOS：`Info.plist` 注册 `CFBundleURLTypes`，`AppDelegate` 将 open-URL 事件转发到 Flutter。
- Windows：当前用户 `Software\\Classes\\downpeed` 注册协议；后续启动通过单实例窗口的 `WM_COPYDATA` 传递链接。
- Linux：desktop entry 声明 `x-scheme-handler/downpeed`；唯一 `GApplication` 通过 open 事件把链接转发给已运行窗口。

发布安装器仍需在目标系统完成实际关联刷新和验收。开发构建通过 Widget/单元测试验证 Dart 行为，通过对应平台 Debug 构建验证原生代码可编译；不能把单平台构建结果视为其他平台的实机注册证据。
