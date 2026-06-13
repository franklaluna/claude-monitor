# ClaudeMonitor — Claude Code 状态监控工具

macOS 菜单栏应用，实时监控 Claude Code 运行状态。

## 技术栈

| 项 | 技术 |
|---|------|
| 语言 | Swift |
| 框架 | AppKit, Foundation |
| 构建 | swiftc (whole-module optimization) |
| 平台 | macOS |

## 功能

- **菜单栏常驻** — 状态栏图标实时显示 Claude Code 状态
- **进程检测** — 自动检测 Claude Code 进程运行状态
- **详情窗口** — 点击展开详细信息面板
- **Touch Bar** — 支持 Touch Bar 显示状态
- **原生应用** — 打包为 .app 原生 macOS 应用

## 快速开始

### 构建
```bash
chmod +x build.sh
./build.sh
```

### 运行
```bash
open ClaudeMonitor.app
```

## 项目结构

```
ClaudeMonitor/
├── Sources/           # Swift 源码
├── Info.plist         # 应用配置
├── AppIcon.icns       # 应用图标
├── build.sh           # 构建脚本
└── README.md
```
