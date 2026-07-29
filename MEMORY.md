# 项目记忆

> 给 AI Agent 的持久化约定，避免重复踩坑。最后更新：v0.5.5

## 项目概览

- **项目**：book_reader —— Flutter 全网搜书/看书/听书 App
- **路径**：`/workspace/book_reader`
- **仓库**：
  - GitHub：`https://github.com/duzou2026/book_reader.git`
  - Gitee（APK 更新源）：`duzou_5aidnf/novel-reader`
- **版本**：见 `pubspec.yaml` 的 `version: x.y.z+build`（build 号每次 +1）

## 构建与发版（重要）

### 不要本地构建

沙箱环境**没有** Flutter SDK / Android SDK，`flutter build apk` 会失败。
**始终用 GitHub Actions 构建**，工作流：`.github/workflows/build-apk.yml`

### 发版流程

1. 编辑 `pubspec.yaml`，bump `version`（如 `0.5.5+20` → `0.5.6+21`）
2. `git add pubspec.yaml && git commit -m "chore: bump version to 0.5.x"`
3. `git tag v0.5.x`
4. `git push origin main && git push origin v0.5.x`
5. GitHub Actions 自动触发：
   - 构建 split-per-abi APK（arm64-v8a / armeabi-v7a / x86_64）
   - 上传到 GitHub Release
   - 同步到 Gitee Release（App 内更新检测走 Gitee）
6. 构建进度：https://github.com/duzou2026/book_reader/actions

### 补传 Gitee（失败重试）

Gitee 上传失败时，手动触发 workflow_dispatch，输入 tag（如 `v0.5.5`），
会跳过构建直接从 GitHub Release 下载并上传到 Gitee。

## App 更新检测流程

- App 启动时 `AppUpdateController.checkOnStartup` 静默检测
- 优先 Gitee Release，失败回退 GitHub Release
- 版本比较用语义化版本（x.y.z），build 号不参与比较
- APK 下载到本地后调系统安装器

## 技术栈

- Flutter + Dart（channel: stable）
- 状态管理：flutter_riverpod（StateNotifierProvider）
- 路由：go_router
- 持久化：Hive（多 Box：book_sources / bookshelf / reading_prefs 等）
- HTML 渲染：flutter_html（书籍简介含 `<br>` 等标签，需富文本渲染）
- 主题：Material 3 + ColorScheme.fromSeed（默认 teal `0xFF00897B`）

## 书源

- 格式：legado 书源 JSON
- 拉取：`RemoteBookSources` 从 GitHub 仓库远程拉取，缓存到独立 Box
  （**不能**写回 `book_sources` box，否则 List JSON 会污染导致 `getAll()` 崩溃）
- 规则解析：`RuleEngine`，支持 `@js:`、`@css:`、XPath 等
- 当前维护的书源：见 `lib/data/remote_book_sources.dart`

## 常见坑

1. **本地构建不可行** → 用 GitHub Actions
2. **书源测试全失败** → 多半是规则过期，换活跃维护的书源库
3. **`book_sources` box 写入 List JSON** → 会崩溃，必须用独立 cache box
4. **APK 签名** → 需要 `KEYSTORE_BASE64` 等 GitHub Secret，没配置则用 debug 签名（无法覆盖安装正式版）
5. **Gitee 上传超时** → 工作流已用 180s 超时 + 5 次重试，单文件失败不阻塞其他文件
