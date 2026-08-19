# Downpeed 桌面发布与验证

本文档定义 M4 桌面发布物的生成、校验和信任边界。当前流程提供可重复的原生构建、Ad-hoc/未签名包、依赖许可证、发布 Manifest 和 SHA256；它不代表 Apple 公证、Windows 可信签名或商店审核。

## 本地命令

```bash
make integration-test
make package
make verify-package
make smoke-package
```

`make integration-test` 在系统临时目录启动应用测试 Runner 和内嵌 Go 动态库，使用本地 Range 服务器验证：

1. 引擎启动与 REST 就绪。
2. HTTP 元数据解析和分段下载。
3. 有实际字节进度后暂停。
4. 引擎重启后恢复暂停任务。
5. 继续下载、原子完成和逐字节内容校验。
6. 再次重启后恢复已完成记录。

测试只监听 Loopback，不访问公网，也不读取或修改用户现有任务数据库。

`make smoke-package` 会依次打包、校验并直接启动准备进入归档的 Release 应用。它通过一次性环境标记为内嵌引擎指定独立 Loopback 端口和临时数据目录，再完成一项本地文件下载与内容校验；普通应用启动不会采用这些覆盖值。macOS 临时目录位于应用自身沙盒容器内，测试结束后只清理本次创建的目录。

## 发布物

每个平台在 `dist/` 生成：

- 桌面包：macOS DMG、Windows ZIP 或 Linux tar.gz。
- `*-THIRD_PARTY_NOTICES.txt`：从 Go `nosqlite` 发布闭包和 Flutter 运行时依赖图生成；开发测试依赖不会进入文件。
- `*-manifest.json`：版本、构建号、提交、构建时间、通道、平台、架构、签名模式、文件大小和 SHA256。
- `*-SHA256SUMS`：桌面包、许可证和 Manifest 的独立校验值。

构建参数会同时注入 Flutter 客户端，“关于与许可证”页可以直接查看版本、提交、发布通道和构建时间。

## 平台校验

| 平台 | 当前包 | 自动校验 |
| --- | --- | --- |
| macOS | Ad-hoc 签名、未公证 DMG | 嵌入动态库、`downpeed` Scheme、完整代码签名链、DMG、Manifest、SHA256、隔离启动与本地下载 |
| Windows | 未签名便携 ZIP | 应用 EXE、内嵌 DLL、Manifest、SHA256、隔离启动与本地下载 |
| Linux | 未签名便携 tar.gz | 应用、内嵌 SO、desktop entry、归档、Manifest、SHA256、隔离启动与本地下载 |

`.github/workflows/desktop-quality.yml` 在三个系统的原生 Runner 上执行集成测试、打包和校验。单个平台成功不能替代其他平台结果；工作流首次运行前，Windows/Linux 仍属于“已配置但未验证”。

## macOS 信任边界

当前 Xcode Release 配置使用 `-` 身份进行 Ad-hoc 签名，嵌入 Framework 与 `libdownpeed.dylib` 由构建系统逐层签名。`make verify-package` 使用 `codesign --verify --deep --strict` 验证包内签名一致性，但 Ad-hoc 签名没有 Apple Developer Team，无法通过 Gatekeeper 的开发者身份验证，也不能提交 Apple 公证。

没有 Apple Developer Program 账号时，DMG 适合本机和明确知情的内部测试。公开下载的用户可能需要在 Finder 中对应用执行“右键 → 打开”并确认来源。不要把关闭 Gatekeeper 或移除系统隔离属性作为常规安装步骤。

接入 Developer ID 时应新增独立的标签发布流程，按由内到外的顺序签名嵌套代码和 App，启用 Hardened Runtime，提交 `notarytool`，装订公证票据后再次运行 `codesign`、`spctl` 和 DMG 校验。开发者凭据只保存在 CI Secret 中，普通分支和拉取请求不能访问。

## 人工验收

自动化完成后仍需在每个目标系统使用干净用户目录检查：

1. 安装或解压发布包并启动应用。
2. 确认内嵌引擎在线、新建本地测试下载并完成。
3. 使用 `downpeed://download?url=...` 唤起已经运行和未运行的应用。
4. 检查托盘恢复、关闭到托盘、登录启动和优雅退出。
5. 确认“关于与许可证”中的构建信息与 Manifest 一致。

自动化未执行这些真实桌面操作时，交付记录必须明确保留人工验收项。
