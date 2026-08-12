# Downpeed 品牌标记

Downpeed 的品牌标记是一座 D 形下载通道：外轮廓对应产品首字母，内部向下箭头表达文件进入本地设备。完整、闭合的轮廓强调稳定与可控，并在菜单栏、任务栏和 16px 小图标中保持清晰识别。

## 视觉规范

- 图标底色：`#20201E`（Graphite）
- 图形前景：`#F7F7F3`（Warm white）
- 风格：中性、克制、可靠；不使用渐变、文字和装饰性品牌色
- 安全区：图标内容位于 1024px 画布的 64px 内边距之内
- 母版：[downpeed-logo.svg](downpeed-logo.svg)
- 浅色界面标记：[downpeed-mark-light.svg](downpeed-mark-light.svg)，前景 `#242421`
- 深色界面标记：[downpeed-mark-dark.svg](downpeed-mark-dark.svg)，前景 `#EDEDE8`

该标记为 Downpeed 原创资产，不复用 Gopeed、Flutter 或 Codex 的品牌图形。Flutter 内的 `DownpeedBrandMark` 使用相同几何，并从当前主题读取前景色，在浅色和深色主题间实时切换；平台启动图标保持中性 Graphite 底板，保证 Dock、任务栏和启动器中的稳定识别。

## 平台资源

- macOS：`app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows：`app/windows/runner/resources/app_icon.ico`
- Linux：`app/linux/runner/resources/app_icon.png`

平台位图均由本目录中的 SVG 母版生成。修改母版后，应重新生成全部尺寸并执行对应平台构建，避免 Dock、任务栏或启动器继续使用旧图标。

macOS 的 AppIcon 位图需要把母版合成到不透明、铺满画布的 Graphite 底色上，由系统统一应用最终圆角蒙版。不要在 macOS 位图中预先裁出圆角或保留外侧留白；macOS 26 会把这种旧式图标缩小后放进系统提供的底板，形成额外的白色外框。Windows 与 Linux 资源继续使用母版的原有安全区。
