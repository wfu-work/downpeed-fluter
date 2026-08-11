# Downpeed 品牌标记

Downpeed 的品牌标记由三条传输轨道汇聚为一个向下落点组成，表达“多任务进入统一、可控的本地下载流程”。几何造型保持紧凑，在菜单栏、任务栏和 16px 小图标中仍能辨认。

## 视觉规范

- 图标底色：`#20201E`（Graphite）
- 图形前景：`#F7F7F3`（Warm white）
- 风格：中性、克制、可靠；不使用渐变、文字和装饰性品牌色
- 安全区：图标内容位于 1024px 画布的 64px 内边距之内
- 母版：[downpeed-logo.svg](downpeed-logo.svg)

该标记为 Downpeed 原创资产，不复用 Gopeed、Flutter 或 Codex 的品牌图形。应用内品牌标记使用相同的“轨道汇聚”几何，但会自动适应界面的深浅主题。

## 平台资源

- macOS：`app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows：`app/windows/runner/resources/app_icon.ico`
- Linux：`app/linux/runner/resources/app_icon.png`

平台位图均由本目录中的 SVG 母版生成。修改母版后，应重新生成全部尺寸并执行对应平台构建，避免 Dock、任务栏或启动器继续使用旧图标。
