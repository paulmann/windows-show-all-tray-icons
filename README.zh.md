# TrayIconGuard v8 «Aurora» 🛡️✨

[![版本](https://img.shields.io/badge/版本-8.6.3-green)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![许可证](https://img.shields.io/badge/许可证-PolyForm%20Noncommercial%201.0.0-orange)](LICENSE)
[![原生 C++17](https://img.shields.io/badge/native-C%2B%2B17-00599C?logo=cplusplus&logoColor=white)](https://en.cppreference.com/w/)
[![零依赖](https://img.shields.io/badge/依赖-零-brightgreen)](docs/BUILD.md)
[![EXE 大小](https://img.shields.io/badge/exe-~1.05%20MB-blue)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/)
[![CI](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml/badge.svg)](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml)
[![Downloads](https://img.shields.io/github/downloads/paulmann/windows-show-all-tray-icons/total?logo=github&color=blue)](https://github.com/paulmann/windows-show-all-tray-icons/releases)
[![Stars](https://img.shields.io/github/stars/paulmann/windows-show-all-tray-icons?logo=github&color=yellow)](https://github.com/paulmann/windows-show-all-tray-icons/stargazers)

<!-- md-i18n:switcher -->
**其他语言：** [English](README.md) · [Deutsch](README.de.md) · 中文 · [हिन्दी](README.hi.md) · [Español](README.es.md) · [Русский](README.ru.md)

📚 [Documentation site](https://paulmann.github.io/windows-show-all-tray-icons/) · [Knowledge base](https://github.com/paulmann/windows-show-all-tray-icons/wiki) · [docs/](docs/)

> **让 Windows 10/11 通知区域（系统托盘）的每一个图标都保持可见——并且一直保持下去。
> 单个原生可执行文件，零依赖，零遥测。**


TrayIconGuard 会把被 Windows 收进溢出弹层的图标重新提回任务栏——并且由**事件驱动的守卫**
在 Explorer 再次隐藏它们的瞬间（应用启动、更新、重新注册）重新提回。它写入的正是 Windows
“设置”开关所使用的同一处注册表存储，仅当前用户、无需管理员权限，并以**一个约 1 MB 的静态
链接 exe** 提供现代 Fluent 界面、无头守护模式与完整 CLI，可在原版 Windows 上直接运行。

![浅色与深色仪表盘、全部页面](shots/preview-2x2.png)

---

## 📋 目录

- [🚀 为什么需要 TrayIconGuard？](#-为什么需要-trayiconguard)
- [✨ 核心特性](#-核心特性)
- [⚡ 快速开始](#-快速开始)
- [📦 安装方式](#-安装方式)
- [🖥️ 界面导览](#-界面导览)
- [🧰 CLI 参考](#-cli-参考)
- [🏗️ 工作原理](#-工作原理)
- [🔄 基于 Git 的自我更新](#-基于-git-的自我更新)
- [🌍 语言](#-语言)
- [🌗 主题与外观](#-主题与外观)
- [🏢 部署与自动化](#-部署与自动化)
- [🔍 故障排查](#-故障排查)
- [🛠️ 从源码构建](#-从源码构建)
- [🗂️ 仓库地图](#-仓库地图)
- [🤝 参与贡献](#-参与贡献)
- [📄 许可证](#-许可证)
- [👨‍ 作者与支持](#-作者与支持)
- [🎯 路线图](#-路线图)

---

## 🚀 为什么需要 TrayIconGuard？

Windows 会“记住”每个托盘图标的可见性——但又** constantly 忘记**：每当应用（重新）注册其
通知图标，Explorer 就会以 `IsPromoted=0` 重建注册表子键，图标于是又掉进 `^` 溢出弹层。
因此一次性修改和 `.reg` 文件往往几小时内就失效。

```text
# 原版 Windows 10/11 上实际发生的事
应用启动 / 更新 / 重新注册托盘图标
        │
        ▼
Explorer 重建 HKCU\Control Panel\NotifyIconSettings\{id}
且 IsPromoted = 0           ← 图标刚刚自己藏起来了
        │
        ▼
TrayIconGuard 监视器（RegNotifyChangeKeyValue，约 400 ms 去抖）
        │
        ▼
IsPromoted = 1 被恢复       ← 图标立刻回到任务栏
```

### 实际收益

- **⚡ 即时**：事件驱动而非轮询——修复在半秒内落地
- **🎯 精准**：逐图标控制、排除规则、拖拽排序、三种可见性模式
- **🛡️ 克制**：仅 HKCU、标准用户、永远不要管理员、无遥测、自启动可选
- **📦 小巧**：单个静态 exe（约 1.05 MB）——无 .NET、无运行时、无 Redistributable
- **🔁 自愈**：扛过 Explorer 重启、应用更新与登录周期

## ✨ 核心特性

### 🛡️ **正确性与安全**

- **与“设置”同级的机制**——写入 `HKCU\Control Panel\NotifyIconSettings` 中的 `IsPromoted`，
  即 Windows 设置开关使用的同一存储（见 [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)）
- **JSON 快照**（schema v8），破坏性操作前自动备份，恢复/导出/删除管理器，保留 30 份
- **优雅降级**：老旧构建上给出清晰状态与 legacy 回退，不崩溃
- **稳定退出码**（`0/1/2/3`），便于脚本与 RMM 集成

### 🎯 **智能守卫引擎**

- **事件监视器**：对存储子树的 `RegNotifyChangeKeyValue` + 去抖，可选轮询回退，
  新图标发现，暂停/恢复
- **可见性模式**：*完整*（全部显示）、*自定义*（按图标的个人选择）、
  *紧凑*（除 TrayIconGuard 外全部隐藏）——托盘菜单或 CLI 均可切换
- **逐图标控制**：显示/隐藏/排除，支持通配符排除（`onedrive.exe`、`*teams*`）
- **拖拽排序**托盘图标顺序，按本机保存
- **安全的 Explorer 重启**：带冷却与确认

### 🎨 **现代 Fluent UI（2026）**

- 自绘 Win32/GDI+ 界面：导航栏、卡片、动画开关、分段控件、悬浮滚动条、
  Per-Monitor-V2 DPI、Windows 11 圆角与深色标题栏
- **浅色 / 深色 / 跟随系统**主题，快捷切换、持久化、首次启动自动识别
- **强调色**：跟随 Windows 或 8 种预设
- 响应式布局（窄于 860 px 时导航栏收起），完整键盘导航

### 📦 **内置安装器**

- 首次运行向导：**范围**（*仅为我* / *为所有用户*——一次 UAC 提示）、安装目录、
  自启动、桌面与开始菜单快捷方式——或*仅运行一次*（便携模式）
- “应用和功能”卸载条目；`--uninstall` 移除一切（需要时自动提权）

### 🔄 **基于 Git 的自我更新**

- 可选检查本仓库 `update/stable.json`，下载带 **SHA-256 钉扎**，自我替换并重启；
  手动按钮 + 可选每日自动检查（仅气泡提示）
- 面向发布工程师的发布契约：[Updater_SKILL.MD](Updater_SKILL.MD)

## ⚡ 快速开始

```text
# 1. 下载最新 Release（exe 或 zip）
https://github.com/paulmann/windows-show-all-tray-icons/releases/latest

# 2. 解除锁定（Mark-of-the-Web）后运行——这就是全部安装步骤
右键 TrayIconGuard.exe → 属性 → 解除锁定 → 确定
TrayIconGuard.exe

# 3. 首次运行：向导询问 范围 / 目录 / 快捷方式
#    …或选择“仅运行一次，不安装”进入便携模式
```

无头 / 一行命令：

```powershell
TrayIconGuard.exe --promote-all          # 立即显示全部，然后退出
TrayIconGuard.exe --watch                # 无头守卫（无 GUI），如用于任务计划程序
TrayIconGuard.exe --status --json        # 机器可读状态，供监控消费
TrayIconGuard.exe --check-update         # 询问 git feed 是否有新版本
```

## 📦 安装方式

| 模式 | 操作 | 管理员？ | 得到什么 |
|---|---|---|---|
| **便携** | 在任意位置运行 exe | ❌ | 除 `%APPDATA%` 设置外不落盘 |
| **仅当前用户**（默认） | 向导 → *仅为我* | ❌ | `%LOCALAPPDATA%\Programs\TrayIconGuard`、HKCU Run 自启动、用户级快捷方式、“应用和功能”条目 |
| **所有用户** | 向导 → *为所有用户* | ✅ 一次（UAC） | `%ProgramFiles%\TrayIconGuard`、HKLM Run 自启动、公共桌面/开始菜单快捷方式、机器级卸载条目 |

卸载：*应用和功能 → TrayIconGuard*，或 `TrayIconGuard.exe --uninstall`。

![安装向导](shots/setup-wizard-light.png)

## 🖥️ 界面导览

| 页面 | 功能 |
|---|---|
| **仪表盘** | 实时计数（已注册 / 任务栏 / 隐藏 / 已排除）、守卫状态、一键操作、系统与最近活动卡片 |
| **托盘图标** | 搜索、过滤、逐图标开关、排除、拖拽排序、行右键菜单 |
| **守卫** | 监视器调优（去抖、轮询、Explorer 重启策略）、legacy 修复、统计、排除列表 |
| **外观** | 主题（浅/深/系统）、强调色、语言、动画、紧凑行 |
| **备份** | 快照列表、创建/恢复/导出/删除、自动备份开关 |
| **活动** | 带级别过滤的日志查看器、导出、打开文件夹 |
| **关于** | 版本、更新面板、许可证与知识库按钮、诊断复制、安装模式徽标 |

深色模式下的“关于”页（更新面板与链接）：

![关于，深色](shots/dark-about.png)

## 🧰 CLI 参考

| 命令 | 作用 |
|---|---|
| *（无参数）* | 启动驻留托盘的 GUI |
| `--minimized` | 启动后隐藏到通知区域 |
| `--show` / `--toggle-guard` | 向运行实例发 IPC（激活 / 暂停-恢复） |
| `--status [--json]` | 打印托盘状态后退出 |
| `--promote-all` | 提升全部隐藏图标后退出 |
| `--restore-defaults` | 删除 `IsPromoted` 值（把控制权交还 Windows） |
| `--restart-explorer` | 安全重启外壳后退出 |
| `--backup` / `--restore-latest` | 创建 / 恢复 JSON 快照 |
| `--watch` | 无头守卫循环（事件驱动，无 GUI） |
| `--install-autostart` / `--uninstall-autostart` | 管理 HKCU Run 自启动项 |
| `--install-machine <dir> [--autostart] [--desktop] [--menu]` | 所有用户安装体（需提权运行） |
| `--uninstall` | 移除快捷方式、自启动与已安装副本（机器级安装时自动提权） |
| `--mode full\|custom\|compact` | 设置托盘可见性模式 |
| `--check-update` / `--update-now` | git feed 检查更新 / 非交互更新 |
| `--version` / `--help` | 自省 |

**退出码：** `0` 成功 · `1` 参数无效 · `2` 操作系统不受支持 · `3` 部分失败。

## 🏗️ 工作原理

主存储（Windows 10 1703+ / 11），按用户、无需管理员：

```text
HKCU\Control Panel\NotifyIconSettings\{<icon-id>}
    IsPromoted            DWORD      1 = 在任务栏，0 = 在溢出弹层
    ExecutablePath       REG_SZ     所属进程
    IconResource         REG_SZ     路径,-id
    IconSnapshot         REG_BINARY 缓存图像
    LastNotificationAddedTime  REG_QWORD
```

Legacy 双保险（可选）：`EnableAutoTray=0`，以及移除 `HKCU\…\Policies\Explorer` 下的
`HideSCA*` 策略。完整研究、失效分析与“勿动”清单（`StuckRects3` 等）：
[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)。

## 🔄 基于 Git 的自我更新

- Feed：`main` 分支的 [`update/stable.json`](update/stable.json)（schema、sha256 钉扎、说明）
- 客户端：WinHTTP 下载 → BCrypt SHA-256 校验 → 改名链自我替换 → 重新启动
- 绝不静默：手动更新有确认对话框；自动检查为可选、≤ 每 24 小时一次、仅气泡
- CI 从**发布实际提供的字节**钉扎 feed（`scripts/make_feed.py`），
  因此 feed 与资产永远不会不一致——见 [Updater_SKILL.MD](Updater_SKILL.MD)

## 🌍 语言

30 个语言环境，逐字符串英文回退，首次启动自动识别系统语言（可在**外观 → 语言**实时切换）：

| | | | |
|---|---|---|---|
| English（默认） | Русский | 中文 (简体) | हिन्दी |
| Español | Deutsch | Français | Português |
| 日本語 | 한국어 | Italiano | العربية |
| Indonesian | اردو | Türkçe | Tiếng Việt |
| Polski | ไทย | Українська | Nederlands |
| Română | Ελληνικά | Čeština | Svenska |
| Magyar | Suomi | Dansk | עברית |
| فارسی | বাংলা | | |

详情与翻译指南：[docs/I18N.md](docs/I18N.md)。

## 🌗 主题与外观

- **浅色 / 深色 / 跟随系统**——持久化、首次启动自动识别、标题栏快捷切换；
  Windows 11 沉浸式深色标题栏与圆角
- **强调色**：跟随 Windows 着色或 8 种内置预设
- **动效**：140 ms 开关滑动与悬停状态（可关闭）、紧凑行模式
- 全界面 Per-Monitor-V2 DPI 正确

## 🏢 部署与自动化

- **任务计划程序 / GPO 登录脚本**：`TrayIconGuard.exe --watch`（无头）或
  `--minimized`（GUI 驻留托盘）
- **RMM / 监控**：`--status --json`、稳定退出码、`%LOCALAPPDATA%\TrayIconGuard\logs`
  中 14 天轮转日志
- **机队安全**：per-user 范围无需管理员；machine 范围在提权上下文中用 `--install-machine`
- 商店就绪：[`store/`](store/) 内含 MSIX 清单 + 资产 + 打包脚本——见 [docs/STORE.md](docs/STORE.md)

## 🔍 故障排查

| 症状 | 处理 |
|---|---|
| 启动报“并行配置不正确” | exe 被解压到名为 `*.exe` 的文件夹或未解除锁定；见 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| 首次运行 SmartScreen 警告 | 未签名二进制的预期行为：属性 → 解除锁定；签名指南见 [docs/SMARTSCREEN.md](docs/SMARTSCREEN.md) |
| 某应用更新后图标又被隐藏 | 守卫被暂停？托盘菜单 → *暂停/恢复*；“活动”页可查看监视器事件 |
| 更新被拒：sha256 mismatch | feed/资产漂移——按 [Updater_SKILL.MD](Updater_SKILL.MD) §3 重新发布 |
| Win10 < 1703 上无任何提升 | 存储不受支持；应用会说明并提供 legacy 开关 |

更多：[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · [wiki FAQ](https://github.com/paulmann/windows-show-all-tray-icons/wiki)

## 🛠️ 从源码构建

```bash
# Linux 交叉编译（静态、strip、零依赖 exe）
sudo apt install g++-mingw-w64-x86-64 cmake
./scripts/build.sh          # 门禁：0 警告、manifest 检查、仅 OS-DLL 审计
./scripts/package.sh        # zip + SHA256SUMS

# 或 Windows 上原生 MSVC
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

CI 在每次 push 上跑两条链路（ubuntu 交叉 + windows MSVC），并在 `v*` 标签时发布 Release。
详见 [docs/BUILD.md](docs/BUILD.md)。

## 🗂️ 仓库地图

| 路径 | 内容 |
|---|---|
| `src/core` | 引擎：注册表存储、守卫、explorer、备份、自启动、安装器、更新器、CLI |
| `src/ui` | Fluent 组件库、页面、向导、托盘、主题、30 语言 i18n |
| `docs/` | 工程与用户文档（HOW-IT-WORKS、CLI、DESIGN、I18N、STORE、SMARTSCREEN…） |
| `store/` | MSIX 清单 + Store 资产 + `make_msix.ps1` |
| `scripts/` | 构建/打包/feed 工具（`build.sh`、`package.sh`、`make_feed.py`） |
| `installer/` | 可选的企业打包辅助 ps1/bat/Inno |
| `update/` | 在线更新 feed（`stable.json`） |
| `.github/workflows/ci.yml` | 门禁 + 发布 + feed 钉扎流水线 |

## 🤝 参与贡献

欢迎 Issue 与 PR。请保持：零运行时依赖、仅 HKCU 的安全模型、无警告构建门禁
（`-Wall -Wextra`）以及 `Updater_SKILL.MD` 的 feed 契约。
贡献规则见 [`CONTRIBUTING.md`](CONTRIBUTING.md) 与[行为准则](CODE_OF_CONDUCT.md)；安全问题请通过 [`SECURITY.md`](SECURITY.md) 报告。

## 📄 许可证

[PolyForm Noncommercial License 1.0.0](LICENSE)——非商业使用自由；商业授权请联系作者。

## 👨‍💻 作者与支持

**Mikhail Deynekin** · <icons@Deynekin.com> · [Deynekin.com](https://Deynekin.com) ·
[GitHub](https://github.com/paulmann) ·
[知识库（wiki）](https://github.com/paulmann/windows-show-all-tray-icons/wiki) ·
[许可证](https://github.com/paulmann/windows-show-all-tray-icons/blob/main/LICENSE)

## 🎯 路线图

- [ ] 代码签名流水线（SmartScreen 声誉）
- [ ] 阿拉伯语/希伯来语/波斯语/乌尔都语的 RTL 布局镜像
- [ ] 面向 SCCM/Intune Win32 应用的 MSI 打包
- [ ] ARM64 原生构建

---

<sub>用 🧡 打造，为了整洁的任务栏。TrayIconGuard 与 Microsoft 无隶属关系。</sub>
