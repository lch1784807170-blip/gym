# CLAUDE.md

## 项目

个人健身计划与训练记录 App，Android 端，只有作者本人使用。

## 硬性约束

- 纯本地应用：不申请 `android.permission.INTERNET`，不引入任何需要联网的依赖（统计、崩溃上报、广告、云同步、远程配置等）。
- 单用户：不做账号、登录、多用户。
- 数据只保存在手机本地。

## 阶段计划

1. 开发环境与项目记忆（已完成）
2. 需求分析
3. 框架梳理：技术栈、UI 框架、架构、目录结构、minSdk / compileSdk 在这一步确定
4. 原型输出
5. 开发测试

需求分析和框架梳理完成前，不要自行决定技术栈、UI 框架或架构。每个阶段的结论定下来后补进本文件。

## 开发环境

### 云端会话（Claude Code）

- 每次会话启动时运行 `.claude/hooks/session-start.sh`：检查 JDK 17+，把 Android SDK（cmdline-tools、platform-tools、`platforms;android-36`、`build-tools;36.0.0`）装到 `~/android-sdk`，并设置 `ANDROID_HOME`。框架梳理阶段定下 compileSdk 后，同步修改脚本顶部的版本号。
- 容器自带 JDK 21 和 Gradle 8.14.3（`/opt/gradle`）。项目骨架建立后统一使用 `./gradlew`。
- Android SDK 和 Google Maven 仓库（AGP、AndroidX）都从 `dl.google.com` 下载。云端环境的网络策略必须允许这个域名，否则无法构建；不要改用第三方镜像绕过。
- 容器没有 `/dev/kvm`，跑不了模拟器。云端只能跑 JVM 单元测试（可配合 Robolectric），界面和真机验证在手机上做。

### 本地

- Android Studio 打开项目，真机通过 USB 或无线调试运行。

## 常用命令（项目骨架建立后）

- 构建：`./gradlew assembleDebug`
- 单元测试：`./gradlew testDebugUnitTest`
- Lint：`./gradlew lintDebug`

## 协作约定

- 和用户沟通、写文档用中文；代码标识符和提交信息用英文。
- 改动走分支 + PR，合入 `main`。
