# BT/Magnet 组件许可证与安全审查

审查日期：2026-08-11  
结论：**有条件批准 `github.com/anacrolix/torrent v1.61.0` 用于 Downpeed 的 BT 协议适配器。** 本结论批准的是精确版本和公开 API 接入方案，不批准复制 Gopeed 源码、修改上游文件或绕过后续发布门禁。

## 决策摘要

| 项目 | 结论 |
| --- | --- |
| 组件 | `github.com/anacrolix/torrent` |
| 固定版本 | `v1.61.0` |
| Go 要求 | 上游 `go 1.24.0`；Downpeed `go 1.25+` 可满足 |
| 许可证 | MPL-2.0 |
| 模块校验和 | `h1:vxo+B4SwnoP5AQWbhvnTYIaTgPSX+llYUVuQVsN4Jg8=` |
| `go.mod` 校验和 | `h1:yKUKuZSSDdyOsCbuH+rDOpswl/g546gICapdrU7aUmQ=` |
| 上游支持策略 | 仅保证最近两个 minor release |
| 使用方式 | Downpeed 自有 `protocol/bt` 适配器通过公开 API 调用，不 Fork、不修改上游文件 |

选择该组件的原因是它覆盖 Torrent v1/v2、Magnet、Tracker、DHT、PEX、TCP/uTP、协议加密和文件优先级，能够在 Go 内核中保持协议适配器边界。其默认配置面向通用 BT 客户端，不等同于 Downpeed 的安全默认值，接入时必须显式覆盖本文件列出的配置。

`github.com/cenkalti/rain/v2` 保留为架构备选，但本次未取得与主候选相同口径的源码、许可证闭包和安全策略证据，因此不批准接入。备选状态不代表其不安全或许可证不兼容，只代表证据不足。

## 许可证结论

`anacrolix/torrent` 根许可证为 MPL-2.0。MPL-2.0 是文件级弱 Copyleft，允许 Downpeed 将未修改的 Covered Software 与自有代码组成 Larger Work，也允许 Downpeed 对自有文件采用独立许可证。二进制分发仍需履行以下义务：

1. 在“关于与许可证”页面和安装包随附材料中保留 MPL-2.0 文本、版权及通知。
2. 告知用户如何及时、合理地取得所分发 MPL Covered Software 的对应源代码；费用不得高于实际分发成本。
3. 如果修改上游 MPL 文件，修改后的文件仍必须以 MPL-2.0 提供源代码。
4. 不使用上游商标、项目名称或标识暗示官方背书。

Downpeed 的策略是**不修改上游源码**，只在自有适配器文件中使用公开 API。若未来确需修改上游文件，必须新开许可证审查并建立对应源码归档和发布流程，不能在普通功能提交中直接完成。

Gopeed 本身采用 GPLv3。本次只参考“其产品使用 BT 组件”这一公开事实，不复制 Gopeed 的 GPLv3 源码、代码结构化实现、品牌资产或包标识。若未来直接组合 Gopeed 代码，应另行评估并满足 GPLv3，当前有条件批准不覆盖该情形。

## 可复现证据

审查策略固化在 [`licenses/bt-dependency-policy.json`](licenses/bt-dependency-policy.json)，包含精确版本、Go module 校验和及以下本地证据哈希：

| 文件 | SHA-256 |
| --- | --- |
| `v1.61.0.mod` | `32f1aa6556a9d11d0cd8bd50e97eab35c02585b3b8db49dbeb64d9445346ea97` |
| `LICENSE` | `1f256ecad192880510e84ad60474eab7589218784b9a50bc7ceee34c2b91f1d5` |
| `SECURITY.md` | `3dc4fc5a4a80d6f6d467600a2b63d8bcf06b6d02d1b5cb0b7fc7d0d78f362bc8` |

在 `backend/` 运行候选证据检查：

```bash
go mod download github.com/anacrolix/torrent@v1.61.0
go run ./cmd/licensecheck -mode candidate
```

第一条命令只把固定版本放入 Go module cache，不修改 Downpeed 的 `go.mod`；门禁本身不会自动下载或替换候选组件。

组件实际进入后端编译图后，必须运行发布模式：

```bash
go run ./cmd/licensecheck -mode release
govulncheck ./...
```

发布模式会 fail closed：

- `go.mod` 必须精确固定 `v1.61.0`，禁止 `replace` 主候选；
- `go.sum` 中模块内容和 `go.mod` 两个校验和必须匹配审查策略；
- 主候选必须真正进入 `go list -deps ./...` 的编译闭包，不能只是未使用的声明依赖；
- 对真实编译闭包逐模块读取根许可证；GPL、AGPL、SSPL、LGPL 和未知许可证会失败并要求人工复核；
- 依赖闭包使用与三平台发布引擎一致的 `CGO_ENABLED=0`；仅在开发机 CGO 构建中可选、不会进入发布二进制的 SQLite piece-completion 实现不计为分发依赖；
- 测试工具、示例、FUSE、Telemetry exporter 等未进入 Downpeed 编译闭包的上游模块声明不会被误计为发布依赖。

2026-08-12 已对真实后端编译图运行 `govulncheck ./...`：Downpeed 当前调用路径中发现 0 个可达漏洞；扫描另报告 imported packages 中 4 个、required modules 中 22 个不可达漏洞。该结果只代表本次固定依赖图和当前调用路径，不等同于组件长期“零已知漏洞”；每次发布仍需重复扫描，若出现可达漏洞必须升级、规避受影响能力或停止接入。

## 供应链与维护要求

- 只接受 Go proxy/sumdb 可验证的固定 tag，不使用分支、`latest` 或未记录伪版本。
- 版本升级必须更新策略文件中的版本、模块和证据哈希，重新执行候选与发布检查。
- 上游只保证最近两个 minor release；Downpeed 每次发布检查最新稳定版，落后超过两个 minor 时阻止发布。
- 不把整个上游源码复制进仓库，不提交 module cache、构建产物或未经审查的补丁。
- 发布包生成第三方许可证清单，并保留该版本上游源码获取地址或源代码归档。
- 对新的原生库、CGO、FUSE、WebRTC、Telemetry exporter 或替代存储后端单独审查；M3 默认不启用这些能力。

## 必须覆盖的上游默认配置

实现复核（2026-08-12）：受限传输适配器已进入编译闭包，但只开放 `.torrent + 显式公网 IPv4 Peer`。安全配置集中关闭 Tracker、DHT、PEX、WebSeed、WebTorrent、IPv6、uTP、端口映射、入站连接、上传和做种，并设置 Peer、half-open 与未校验数据上限。`TorrentSpec` 会清除 Tracker、WebSeed、DHT node、PeerAddrs 和 metadata Sources，同时保留初始 Piece 校验。引擎现在持久化并执行 1–80 的 Peer 连接预算，但对 Tracker、DHT、PEX、WebSeed、IPv6、入站、上传和做种仍实施 fail closed，任何尝试开启的设置请求都被拒绝。连接诊断只读取运行中 Torrent 统计，不开放额外网络能力；Peer IPv4 在 Go 内核中脱敏为 `/16` 网络前缀与端口后才进入 API，短期 Peer 列表不持久化。

复核同时确认 `v1.61.0/tracker/http/client.go` 的 HTTPS Tracker transport 使用 `InsecureSkipVerify: true`。因此本次批准不包含公共 Tracker 网络能力；不得通过普通配置项重新启用上游自动 Tracker。公共 Tracker 需要 Downpeed 自有安全 Tracker 适配器，或升级到修复后版本并重新完成许可证、安全与漏洞门禁。

`NewDefaultClientConfig` 的若干默认值不符合 Downpeed 的产品边界。适配器不得直接使用默认配置后只修改下载目录，必须集中构造并测试安全配置：

| 上游默认行为 | Downpeed 接入要求 |
| --- | --- |
| 监听所有地址、固定端口 | 使用随机端口；不为远程控制开放 HTTP API；BT 监听范围和 UI 状态必须明确 |
| 默认端口转发可用 | `NoDefaultPortForwarding = true`，M3 不启用 UPnP/NAT-PMP |
| DHT、PEX 默认开启 | 公共 Torrent 才可按设置启用；私有 Torrent 强制关闭，且提供全局隐私开关 |
| IPv6 默认开启 | 首版默认关闭，完成等价的地址过滤和测试后再开放 |
| 上传不限速 | 显式设置上传限速；完成后默认停止，不自动长期做种 |
| 接受连接限流默认关闭 | `DisableAcceptRateLimiting = false`，并设置全局/单任务连接上限 |
| WebTorrent、WebSeed 默认可用 | M3 默认关闭，完成 WebRTC 与 SSRF 独立审查后才能启用 |
| Tracker/HTTP 使用通用拨号 | 注入 Downpeed 的 DNS 解析、私网地址过滤、重定向校验和超时 Transport |

具体资产、边界、滥用场景和数值上限见 [`security/bt-threat-model.md`](security/bt-threat-model.md)。

## 接入验收条件

受限 `.torrent + 显式公网 IPv4 Peer` 传输已经满足当前验收门禁。以下条件继续作为公共 Tracker、DHT、PEX、Magnet 元数据获取、上传和做种能力的开放门禁：

1. 发布模式许可证门禁通过并保存输出。
2. `govulncheck ./...` 对真实后端编译图通过；不可达漏洞需记录模块、符号和判断依据。
3. 安全配置具有单元测试，证明 UPnP、WebTorrent、WebSeed、IPv6、自动做种和无限上传不会因上游默认值意外开启。
4. 新开放的 Tracker、Peer discovery、DHT、PEX、上传入口逐项实现威胁模型中的限制；未实现的能力保持强制关闭。
5. 发布物提供 MPL-2.0 许可证、版权通知和 Covered Software 源代码获取方式。
