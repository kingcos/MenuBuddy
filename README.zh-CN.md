# MenuBuddy

[English](README.md)

一只住在 macOS 菜单栏的小桌宠。点击图标打开面板，看看你的伙伴——一个由你的电脑独一无二生成的 ASCII 动画小生物。

## 功能特性

### 桌宠

- **18 个物种**（可在图鉴中浏览）：鸭子、大鹅、史莱姆、猫咪、龙、章鱼、猫头鹰、企鹅、乌龟、蜗牛、小鬼、六角恐龙、水豚、仙人掌、机器人、兔子、蘑菇、肥肥
- **5 个稀有度**：普通 (60%) → 优秀 (25%) → 稀有 (10%) → 史诗 (4%) → 传说 (1%) —— 各有独特颜色和帽子
- **1% 闪光**变体，金色光芒
- **确定性生成**：由电脑 UUID 派生——同一台电脑，永远同一只
- **待机动画**：3 帧循环动作 + 眨眼，500ms 节拍
- **对话气泡**：每 15-45 秒显示种类专属或通用台词，渐隐效果
- **抚摸互动**：点击精灵触发爱心特效；1、5、10、25、50、100 次有里程碑消息
- **属性面板**：调试力 / 耐心值 / 混乱度 / 智慧值 / 嘴贱度——影响 AI 反应的性格特征
- **物种图鉴**：18 种物种网格展示，点击可预览各稀有度下的外观
- **稀有度着色**：精灵以稀有度颜色渲染（灰/绿/蓝/紫/金）

### AI 反应（大模型驱动）

配置 LLM API 后，伙伴会根据自身属性生成上下文相关的反应：

- **嘴贱度 ≥50** → 毒舌吐槽
- **混乱度 ≥50** → 不可预测、随机
- **智慧值 ≥50** → 深沉、哲理
- **耐心值 <25** → 急躁不耐烦
- **调试力 ≥50** → 技术梗、编程引用

在 设置 → AI 反应 中配置：
- 支持任何 OpenAI 兼容 API（默认 DeepSeek，也支持 OpenAI、Ollama 等）
- Token 用量追踪，可重置
- 测试按钮验证连接
- 未配置时回退到预设台词

### 可插拔触发源系统

任何数据源都可以通过标准化的插件架构驱动桌宠反应：

```
┌───────────────┐  ┌──────────────┐  ┌───────────────┐
│ 系统监控       │  │ 股票价格      │  │ 你的脚本       │
│ (内置)         │  │ (脚本)        │  │               │
└──────┬────────┘  └──────┬───────┘  └───────┬───────┘
       │ TriggerEvent     │                   │
       ▼                  ▼                   ▼
  ┌──────────────────────────────────────────────────┐
  │              TriggerManager                      │
  │  路由事件 → 心情、话语、指示器、表情               │
  │  可选 → LLM 生成上下文相关的 AI 反应              │
  └──────────────────────────────────────────────────┘
```

**内置：系统监控** —— 对 Mac 实时状态做出反应：

| 指标 | 阈值 | 指示器 | 表情 |
|------|------|--------|------|
| CPU | >70% | 🔥 | 😰 压力眼 (×) |
| 内存 | >85% 已用 | 🧠 | 😵 波浪眼 (~) |
| 网速 | >5 MB/s | ⚡ | 🚀 |
| 网速 | 活跃后变空闲 | 🐌 | 平线眼 (_) |
| 磁盘 I/O | >50 MB/s | 💾 | 圆眼 (o) |
| 电量 | <20% | 🪫 | 小点眼 (.) |
| 电量 | 充电中 | ⚡ | — |
| 空闲 | CPU <10%，无网络 | — | 😴 |

**脚本触发源（无需编码）：**

将可执行脚本放入 `~/.menubuddy/triggers/`，应用会定期运行并读取 stdout 的 JSON。在设置中点"重新扫描脚本"即可加载新脚本，无需重启。

```bash
#!/bin/bash
# ~/.menubuddy/triggers/stock.sh
echo '{"interval":60,"trigger":{"indicator":"📈","quips":["涨了!"],"mood":"🤑"},"metrics":[{"label":"AAPL","value":"$254","trend":"↑"}]}'
```

参见 `Examples/triggers/` 中的完整示例（股票价格、网速、CPU/内存）。

使用 `Examples/TRIGGER_PROMPT.md` 可以让任何 AI 助手为你生成自定义触发脚本。

**JSON 格式：**

| 字段 | 必填 | 说明 |
|------|------|------|
| `interval` | 否 | 轮询间隔（秒，默认 60，最小 5） |
| `trigger.indicator` | 是* | 菜单栏 emoji（如 "📈"） |
| `trigger.quips` | 否 | 对话气泡文字（随机选一条） |
| `trigger.mood` | 否 | 伙伴心情 emoji |
| `trigger.eyeOverride` | 否 | 菜单栏表情眼睛字符 |
| `trigger.duration` | 否 | 指示器持续时间（默认 30 秒） |
| `metrics[].label` | 是* | 指标标签（如 "AAPL"） |
| `metrics[].value` | 是* | 指标值（如 "$189"） |
| `metrics[].alert` | 否 | 是否橙色高亮（默认 false） |
| `metrics[].trend` | 否 | "↑"、"↓" 或 "" |

\* 在各自对象内必填；`trigger` 和 `metrics` 本身都是可选的顶层字段。

### 菜单栏

- **动画脸**：伙伴的脸以稀有度颜色在菜单栏中动画显示
- **触发指示器**：事件触发时在脸旁显示 emoji
- **菜单栏话语**：伙伴定期在菜单栏说两句（可配置）
- **勿扰模式**：设置勿扰时段（支持跨午夜，如 22:00→08:00）
- **启动问候**：每次启动随机问候

### 界面与交互

- **左键点击**：打开/关闭面板
- **右键点击**：上下文菜单（摸摸、重命名、静音、开机自启、设置、退出）
- **面板工具栏**：设置、物种图鉴、退出
- **设置**：通用、语言、菜单栏、触发源、AI 反应、日志、重置
- **物种图鉴**：浏览全部 18 种物种，可预览各稀有度外观
- **日志**：可选的文件日志，写入 `~/.menubuddy/logs/`（保留 7 天）
- **LSUIElement**：无 Dock 图标，仅存在于菜单栏

### 国际化

- 完整支持**英文**和**简体中文**（zh-Hans）
- 300+ 个本地化字符串
- 应用内语言切换（跟随系统 / EN / 中文）

## 系统要求

- macOS 14+
- Swift 5.9+（Xcode 15+）

## 构建

```bash
make build    # swift build -c release，生成 .build/release/MenuBuddy.app（临时签名）
make run      # 构建并打开 .app
make install  # 构建并拷贝到 /Applications/MenuBuddy.app
make clean    # swift package clean
```

## 项目结构

```
Sources/MenuBuddy/
├── main.swift                     # 入口
├── L10n.swift                     # 本地化辅助 + Strings 枚举
├── App/AppDelegate.swift          # NSStatusItem、NSPopover、右键菜单、睡眠/唤醒
├── Models/
│   ├── CompanionTypes.swift       # Species、Rarity、Eye、Hat、StatName 枚举
│   ├── CompanionModel.swift       # Mulberry32 PRNG + FNV-1a，确定性生成
│   └── CompanionStore.swift       # 状态管理、触发路由、LLM 集成
├── Triggers/
│   ├── TriggerPlugin.swift        # TriggerSource 协议、TriggerEvent、TriggerMetric
│   ├── TriggerManager.swift       # 中心枢纽：注册源、路由事件
│   ├── SystemTriggerSource.swift  # 内置系统监控触发源
│   └── ScriptTriggerSource.swift  # 脚本触发源（~/.menubuddy/triggers/）
├── System/
│   ├── SystemMonitor.swift        # CPU、内存、网速、磁盘 I/O、电池轮询
│   ├── LLMService.swift           # OpenAI 兼容 API 客户端，用于 AI 反应
│   └── Logger.swift               # 文件日志，按天轮转
├── Sprites/
│   ├── SpriteData.swift           # 18 种物种的 ASCII 艺术帧
│   └── SpriteRenderer.swift       # renderSprite()、renderFace()
└── Views/
    ├── CompanionView.swift        # AnimationEngine、对话气泡、属性、指标条
    ├── PopoverView.swift          # 主面板 UI + 工具栏
    ├── SettingsView.swift         # 设置窗口
    └── SpeciesAtlasView.swift     # 物种图鉴 + 稀有度预览

Resources/
├── en.lproj/Localizable.strings
├── zh-Hans.lproj/Localizable.strings
└── Info.plist

Examples/
├── triggers/                      # 示例触发脚本
│   ├── stock-aapl.sh              # AAPL 股票（东方财富 API）
│   ├── network-speed.sh           # 网速监控
│   ├── cpu-memory.sh              # CPU 和内存监控
│   └── random-mood.sh             # 最简示例
└── TRIGGER_PROMPT.md              # 用 AI 生成自定义触发脚本的提示词
```

## 伙伴生成原理

你的伙伴由电脑的 IOPlatformUUID 确定性生成：先经过加盐 + FNV-1a 32 位哈希，再送入 Mulberry32 伪随机数生成器。生成序列依次决定稀有度、物种、眼睛样式、帽子、闪光概率和属性——相同输入永远产生相同输出。

只有伙伴的**名字**保存在 UserDefaults 中。其他一切都在运行时从电脑 UUID 派生。

## 作者

**kingcos** — [github.com/kingcos/MenuBuddy](https://github.com/kingcos/MenuBuddy)

## 致谢

伙伴设计灵感来自 Claude Code buddy 系统。
