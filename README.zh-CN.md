# MenuBuddy

[English](README.md)

一只住在 macOS 菜单栏的小桌宠。点击图标打开面板，看看你的伙伴——一个由你的电脑独一无二生成的 ASCII 动画小生物。

## 功能特性

### 桌宠

- **18 个物种**：鸭子、大鹅、史莱姆、猫咪、龙、章鱼、猫头鹰、企鹅、乌龟、蜗牛、小鬼、六角恐龙、水豚、仙人掌、机器人、兔子、蘑菇、肥肥
- **5 个稀有度**：普通 (60%) → 优秀 (25%) → 稀有 (10%) → 史诗 (4%) → 传说 (1%)
- **1% 闪光**变体，金色光芒
- **确定性生成**：伙伴由你的电脑 UUID 派生——同一台电脑，永远同一只
- **待机动画**：3 帧循环动作 + 眨眼，500ms 节拍
- **对话气泡**：每 15-45 秒显示种类专属或通用台词，渐隐效果
- **抚摸互动**：点击精灵触发爱心特效；在第 1、5、10、25、50、100 次有里程碑消息
- **属性面板**：调试力 / 耐心值 / 混乱度 / 智慧值 / 嘴贱度——由种类和稀有度决定的性格特征（悬停可查看说明）
- **重命名**：通过表头铅笔图标、右键菜单或设置
- **重置**：换一个新名字的伙伴（外观不变——由电脑硬件决定）

### 可插拔的触发源系统

MenuBuddy 使用**插件架构**来驱动桌宠的反应。任何数据源都可以成为触发源——系统状态、股票价格、天气、CI/CD 状态等。每个触发源独立监控数据，并产生标准化的事件来驱动桌宠的表情、话语、心情和菜单栏指示器。

```
┌───────────────┐  ┌──────────────┐  ┌───────────────┐
│ 系统监控       │  │ 股票价格      │  │ 你的插件       │
│ (内置)         │  │ (示例)        │  │               │
└──────┬────────┘  └──────┬───────┘  └───────┬───────┘
       │ TriggerEvent     │                   │
       ▼                  ▼                   ▼
  ┌──────────────────────────────────────────────────┐
  │              TriggerManager                      │
  │  路由事件 → 心情、话语、指示器、表情               │
  └──────────────────────────────────────────────────┘
```

**内置：系统监控** ——对 Mac 的实时状态做出反应：

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

**编写自定义触发源：**

```swift
class StockTriggerSource: TriggerSource {
    let id = "stock"
    var displayName: String { "股票监控" }
    var isEnabled = true
    var onTrigger: ((TriggerEvent) -> Void)?

    func start() {
        // 轮询数据源，然后发送事件：
        onTrigger?(TriggerEvent(
            sourceId: id,
            indicator: "📈",                          // 菜单栏 emoji
            quips: ["苹果涨了 5%！", "起飞！"],          // 对话气泡
            mood: "🤑",                               // 桌宠心情
            eyeOverride: "$"                           // 菜单栏表情眼睛
        ))
    }

    func stop() { /* 清理资源 */ }

    // 可选：提供实时指标用于状态条显示
    var currentMetrics: [TriggerMetric] {
        [TriggerMetric(label: "AAPL", value: "$189", alert: false, trend: "↑")]
    }
}

// 注册：
store.triggerManager.register(StockTriggerSource())
```

每个注册的触发源都会出现在 设置 → 触发源 中，可独立开关。

### 菜单栏

- **动画脸**：伙伴的脸在菜单栏中以眨眼和待机帧动画显示
- **触发指示器**：事件激活时在脸旁显示 emoji（持续时间后自动消失）
- **菜单栏话语**：伙伴偶尔在菜单栏表情旁说两句（每 2-5 分钟，6 秒后消失）
- **勿扰模式**：在设置中配置勿扰时段，抑制菜单栏话语（支持跨午夜，如 22:00→08:00）

### 感知能力

- **睡眠/唤醒**：Mac 唤醒时伙伴会问候你，根据睡眠时长显示不同消息
- **工作空间**：切换到编程、终端、浏览器、聊天、设计或音乐应用时，25% 概率评论
- **时段问候**：每天第一次打开面板时，根据当前时段问候（早上好/下午好/晚上好/这么晚还没睡？）

### 界面与交互

- **左键点击**：打开/关闭面板
- **右键点击**：上下文菜单，包含摸摸、重命名、静音、开机自启、设置、关于、退出
- **面板工具栏**：底部有设置齿轮、信息和退出按钮——无需右键即可访问
- **设置窗口**：通用、语言、菜单栏、勿扰模式、触发源、使用说明、重置等分区
- **应用内语言切换**：跟随系统 / English / 简体中文
- **开机自启动**：通过 SMAppService 实现
- **静音**：关闭所有对话气泡和菜单栏话语
- **LSUIElement**：无 Dock 图标，仅存在于菜单栏

### 国际化

- 完整支持**英文**和**简体中文**（zh-Hans）
- 270+ 个本地化字符串，覆盖所有界面、台词、属性、系统消息和无障碍标签
- 支持应用内语言切换或跟随系统语言设置

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
│   └── CompanionStore.swift       # 状态管理、触发路由、菜单栏话语、勿扰模式
├── Triggers/
│   ├── TriggerPlugin.swift        # TriggerSource 协议、TriggerEvent、TriggerMetric
│   ├── TriggerManager.swift       # 中心枢纽：注册源、路由事件、持久化状态
│   └── SystemTriggerSource.swift  # 内置系统监控触发源（CPU/内存/网速/电量）
├── System/
│   └── SystemMonitor.swift        # 底层 CPU、内存、网速、磁盘 I/O、电池轮询
├── Sprites/
│   ├── SpriteData.swift           # 18 种物种的 ASCII 艺术帧
│   └── SpriteRenderer.swift       # renderSprite()、renderFace()
└── Views/
    ├── CompanionView.swift        # AnimationEngine、对话气泡、属性面板、指标条
    ├── PopoverView.swift          # 主面板 UI + 工具栏
    └── SettingsView.swift         # 设置窗口 + 触发源开关

Resources/
├── en.lproj/Localizable.strings       # 英文字符串
├── zh-Hans.lproj/Localizable.strings  # 简体中文字符串
└── Info.plist                         # Bundle 配置 + 本地化声明
```

## 伙伴生成原理

你的伙伴由电脑的 IOPlatformUUID 确定性生成：先经过加盐 + FNV-1a 32 位哈希，再送入 Mulberry32 伪随机数生成器。生成序列依次决定稀有度、物种、眼睛样式、帽子、闪光概率和属性——相同输入永远产生相同输出。

只有伙伴的**名字**保存在 UserDefaults 中。其他一切都在运行时从电脑 UUID 派生，所以修改偏好设置无法伪造传说级伙伴。

## 致谢

伙伴设计灵感来自 Claude Code buddy 系统（`buddy/` 文件夹）。
