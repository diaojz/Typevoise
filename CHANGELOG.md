# CHANGELOG

本文件记录项目的重要变更。

## [Unreleased]

### Added - 新增功能
- [2026-04-08] 新增主窗口侧边导航与概览页入口
  - **问题**：原界面以单页和弹窗为主，首次引导、历史记录、设置分散，菜单栏入口也无法直接跳转到关键页面。
  - **解决方案**：在主窗口引入 `AppSection` 分区与侧边栏导航，新增 `OverviewPageView` 作为统一工作台；通过 `Notification.Name.appNavigationRequested` 与 `ContentView.openWindow(for:)` 实现从状态栏菜单到指定页面（概览/历史/设置）的导航。
  - **影响范围**：`Typevoise/ContentView.swift`、`Typevoise/Managers/StatusBarController.swift`、`Typevoise/TypevoiseApp.swift`
  - **测试**：启动应用后从状态栏菜单分别点击“打开主窗口”“历史记录”“设置”，确认都能激活应用并进入对应页面。

### Changed - 功能改进
- [2026-04-08] 重构历史记录页为双栏布局并增强可读性
  - **改进内容**：历史页从传统 `NavigationView` 调整为左侧列表 + 右侧详情的工作区模式，增加默认选中逻辑与空态引导，提升浏览与复制效率。
  - **技术方案**：重写 `HistoryView` 布局结构，新增 `ensureSelection()` 保障列表与详情联动；`HistoryRowView` 增加选中态渐变样式，`DetailView` 抽取 `detailSection` 统一“润色文本/原始文本”展示。
  - **性能提升**：减少频繁切换上下文导致的视图跳转成本，列表浏览与详情对照在同屏完成。
  - **影响范围**：`Typevoise/Views/HistoryView.swift`
  - **测试**：在有/无历史记录两种场景下检查搜索、选中、复制、删除、清空流程是否正常。

- [2026-04-08] 改造设置页与欢迎页为统一的大屏流程体验
  - **改进内容**：设置页改为卡片化分区（API、快捷键、输入行为）并提供保存反馈；欢迎页改为嵌入主窗口的三步引导，完成后回到概览页。
  - **技术方案**：`SettingsView` 使用 `settingsCard` 与 `labeledField` 统一结构，保存后显示状态文案；`WelcomeView` 新增 `onComplete` 回调并在 `completeSetup()` 中触发，避免额外关闭窗口逻辑。
  - **影响范围**：`Typevoise/Views/SettingsView.swift`、`Typevoise/Views/WelcomeView.swift`、`Typevoise/ContentView.swift`
  - **测试**：首次启动按步骤完成配置，确认可进入概览页；在设置页修改 API/自动粘贴/快捷键后确认保存反馈正常。

### Fixed - 问题修复
- [2026-04-08] 修复菜单栏应用在 Dock 可见性与窗口重开上的体验断层
  - **问题现象**：原配置为纯菜单栏形态（`LSUIElement = true`），主窗口化改造后缺少稳定的窗口重开与显式入口。
  - **根本原因**：应用已演进为“菜单栏 + 主窗口协作”模式，但构建配置与窗口生命周期仍按旧模式运行。
  - **解决方案**：将 `LSUIElement` 调整为 `false`（`Info.plist` 与 `project.pbxproj` 同步），并在 `AppDelegate.applicationShouldHandleReopen` 中补充无可见窗口时的重开逻辑；同时在 app commands 中提供“显示主窗口”。
  - **影响范围**：`Typevoise/Info.plist`、`Typevoise.xcodeproj/project.pbxproj`、`Typevoise/TypevoiseApp.swift`
  - **测试**：关闭主窗口后点击 Dock 图标，确认可重新打开概览页；通过菜单命令“显示主窗口”可拉起主窗口。
