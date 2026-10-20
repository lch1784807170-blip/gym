#!/bin/bash
# SessionStart hook：为 Claude Code 云端会话准备 Android 构建环境。
# 只在云端会话（CLAUDE_CODE_REMOTE=true）里执行；本地用 Android Studio 开发时不需要它。
#
# 做的事：
#   1. 检查 JDK 版本（AGP 需要 17+）
#   2. 安装 Android SDK 命令行工具、platform-tools、platform、build-tools
#   3. 把 ANDROID_HOME 等环境变量写入会话
#   4. 如果项目里已有 gradlew，预热 Gradle 依赖缓存
#
# 任何一步失败都不会阻止会话启动；失败原因会通过 stdout 告诉 Claude。
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# SDK 版本：框架梳理阶段确定 compileSdk / buildTools 后同步更新这里。
CMDLINE_TOOLS_BUILD="13114758"
SDK_PACKAGES=("platform-tools" "platforms;android-36" "build-tools;36.0.0")

ANDROID_SDK="${ANDROID_HOME:-$HOME/android-sdk}"
SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

log() { echo "[session-start] $*" >&2; }

# stdout 会作为上下文交给 Claude，只在出问题时输出。
report() { echo "Android 环境准备未完成：$*"; }

persist_env() {
  [ -n "${CLAUDE_ENV_FILE:-}" ] || return 0
  {
    echo "export ANDROID_HOME=\"$ANDROID_SDK\""
    echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK\""
    echo "export PATH=\"$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:\$PATH\""
  } >> "$CLAUDE_ENV_FILE"
}

java_major=$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java.specification.version = //p')
if [ -z "$java_major" ] || [ "$java_major" -lt 17 ]; then
  report "需要 JDK 17 或更高版本，当前是 '${java_major:-未安装}'。"
  exit 0
fi

if [ ! -x "$SDKMANAGER" ]; then
  log "安装 Android SDK 命令行工具 ($CMDLINE_TOOLS_BUILD) 到 $ANDROID_SDK"
  tmp=$(mktemp -d)
  url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"
  if ! curl -fsSL --retry 3 -o "$tmp/cmdline-tools.zip" "$url"; then
    rm -rf "$tmp"
    report "无法从 dl.google.com 下载 Android SDK（可能被云端环境的网络策略拦截）。需要在项目的云端环境设置里允许 dl.google.com。"
    exit 0
  fi
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  rm -rf "$ANDROID_SDK/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
  rm -rf "$tmp"
fi

missing=()
for pkg in "${SDK_PACKAGES[@]}"; do
  [ -d "$ANDROID_SDK/${pkg//;//}" ] || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
  log "安装 SDK 组件: ${missing[*]}"
  yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$ANDROID_SDK" --licenses >/dev/null 2>&1
  if ! "$SDKMANAGER" --sdk_root="$ANDROID_SDK" --install "${missing[@]}" >/dev/null; then
    report "sdkmanager 安装 ${missing[*]} 失败。"
    persist_env
    exit 0
  fi
fi

persist_env
export ANDROID_HOME="$ANDROID_SDK" ANDROID_SDK_ROOT="$ANDROID_SDK"

if [ -x "$PROJECT_DIR/gradlew" ]; then
  log "预热 Gradle 依赖缓存"
  if ! (cd "$PROJECT_DIR" && ./gradlew --no-daemon --quiet help >/dev/null); then
    report "./gradlew help 失败，Gradle 依赖可能没有下载完整。"
  fi
fi

log "完成：ANDROID_HOME=$ANDROID_SDK"
exit 0
