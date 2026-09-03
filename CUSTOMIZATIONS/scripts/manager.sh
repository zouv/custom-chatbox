#!/usr/bin/env bash
# =============================================================================
# manager.sh — chatbox 自定义版项目统一入口
# Windows 使用 Git Bash 执行：sh CUSTOMIZATIONS/scripts/manager.sh <command>
#
# 常用快捷写法（在仓库根目录）：
#   sh CUSTOMIZATIONS/scripts/manager.sh help
#   sh CUSTOMIZATIONS/scripts/manager.sh unpacked
#   sh CUSTOMIZATIONS/scripts/manager.sh setup
# =============================================================================
set -euo pipefail

# 项目根目录：脚本位于 <repo>/CUSTOMIZATIONS/scripts/ 下
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/CUSTOMIZATIONS/scripts"
RELEASE_DIR="${PROJECT_ROOT}/release/build"

log()  { printf "\033[1;34m[manager]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok  ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn ]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[err  ]\033[0m %s\n" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "缺少命令：$1"
    exit 1
  }
}

# 进入项目根目录执行所有命令，避免相对路径歧义
cd "${PROJECT_ROOT}"

# -----------------------------------------------------------------------------
# 7za shim 状态检查（CUSTOM-20260902-003）
# 本机（Windows 非管理员、未开开发者模式）无 symlink 权限时，electron-builder
# 解压 winCodeSign 缓存会因 7za 退出码 2 中断打包。shim 转调真实 7za 并补齐
# dylib。pnpm install 会重置 node_modules，之后需重装 shim。
# -----------------------------------------------------------------------------
ensure_7za_shim() {
  local sevenzip_dir="${PROJECT_ROOT}/node_modules/7zip-bin/win/x64"
  if [ -f "${sevenzip_dir}/7za-real.exe" ]; then
    ok "7za shim 已安装"
    return 0
  fi
  if [ ! -f "${sevenzip_dir}/7za.exe" ]; then
    err "未找到 ${sevenzip_dir}/7za.exe，请先执行 pnpm install"
    exit 1
  fi
  warn "7za shim 未安装，正在安装（pnpm install 后需重做）..."
  if [ ! -f "${SCRIPTS_DIR}/7za-shim.exe" ]; then
    err "缺少 ${SCRIPTS_DIR}/7za-shim.exe，需先编译：csc -out:CUSTOMIZATIONS\\scripts\\7za-shim.exe CUSTOMIZATIONS\\scripts\\7za-shim.cs"
    exit 1
  fi
  mv "${sevenzip_dir}/7za.exe" "${sevenzip_dir}/7za-real.exe"
  cp "${SCRIPTS_DIR}/7za-shim.exe" "${sevenzip_dir}/7za.exe"
  ok "7za shim 安装完成"
}

# 结束可能驻留后台的 Chatbox 实例，否则打包产物被占用会失败
kill_running_chatbox() {
  log "结束正在运行的 Chatbox 实例..."
  taskkill //F //IM Chatbox.exe >/dev/null 2>&1 || true
}

cmd_install() {
  require_cmd pnpm
  log "安装依赖（pnpm install）"
  pnpm install
  ensure_7za_shim
  ok "依赖安装完成"
}

cmd_dev() {
  require_cmd pnpm
  log "启动开发模式（热重载）"
  pnpm run dev "$@"
}

cmd_build() {
  require_cmd pnpm
  log "生产构建（main + preload + renderer）"
  pnpm run build
  ok "构建完成"
}

cmd_lint() {
  require_cmd pnpm
  log "Biome 代码检查"
  pnpm run lint "$@"
  ok "检查完成"
}

cmd_test() {
  require_cmd pnpm
  log "运行测试（vitest）"
  pnpm run test "$@"
  ok "测试完成"
}

# unpacked 包：构建 + electron-builder（--dir），产物为 release/build/win-unpacked/
cmd_unpacked() {
  require_cmd pnpm
  ensure_7za_shim
  kill_running_chatbox
  log "打包 unpacked 目录包（bat）"
  cmd //c "$(cygpath -w "${SCRIPTS_DIR}/build-unpacked.bat" 2>/dev/null || echo "${SCRIPTS_DIR}/build-unpacked.bat")"
  ok "unpacked 打包完成：${RELEASE_DIR}/win-unpacked/"
}

# Setup 包：构建 + electron-builder（NSIS），产物为 release/build/Chatbox-<版本>-Setup.exe
cmd_setup() {
  require_cmd pnpm
  ensure_7za_shim
  kill_running_chatbox
  log "打包 NSIS Setup 安装包（bat）"
  cmd //c "$(cygpath -w "${SCRIPTS_DIR}/build-setup.bat" 2>/dev/null || echo "${SCRIPTS_DIR}/build-setup.bat")"
  ok "Setup 打包完成，见 ${RELEASE_DIR}/"
}

# 汇总当前打包产物
cmd_artifacts() {
  if [ ! -d "${RELEASE_DIR}" ]; then
    warn "尚无打包产物（${RELEASE_DIR} 不存在）"
    return 0
  fi
  log "当前打包产物（${RELEASE_DIR}）："
  local found=0
  for f in "${RELEASE_DIR}"/*.exe "${RELEASE_DIR}"/*.blockmap "${RELEASE_DIR}"/*.yml; do
    [ -f "$f" ] || continue
    found=1
    printf "  %s  (%s bytes)\n" "$(basename "$f")" "$(stat -c %s "$f" 2>/dev/null || wc -c < "$f" | tr -d ' ')"
  done
  for d in "${RELEASE_DIR}"/*-unpacked; do
    [ -d "$d" ] || continue
    found=1
    printf "  %s/  (目录包)\n" "$(basename "$d")"
  done
  [ "$found" = 0 ] && warn "产物目录为空"
}

cmd_clean() {
  log "清理构建与打包产物"
  rm -rf "${PROJECT_ROOT}/out" "${PROJECT_ROOT}/dist" "${PROJECT_ROOT}/release/build" "${PROJECT_ROOT}/release/app/dist" "${PROJECT_ROOT}/release/app/node_modules"
  ok "清理完成"
}

cmd_help() {
  cat <<'EOF'
chatbox-custom — manager.sh

用法：
  sh CUSTOMIZATIONS/scripts/manager.sh <command> [args]

命令：
  install [args]  安装依赖并装好 7za shim（pnpm install）
  dev    [args]   启动开发模式（热重载）
  build  [args]   生产构建（main + preload + renderer）
  lint   [args]   Biome 代码检查
  test   [args]   运行测试（vitest）
  unpacked        构建 + 打包 unpacked 目录包（免安装，release/build/win-unpacked/）
  setup           构建 + 打包 NSIS Setup 安装包（release/build/Chatbox-<版本>-Setup.exe）
  artifacts       列出当前打包产物
  clean           清理构建、打包产物
  help            显示帮助

说明：
  - unpacked/setup 会自动：检查/安装 7za shim、结束运行中的 Chatbox.exe。
  - 正式发布（GitHub Release、版本号管理）请用 chatbox-release skill，
    本脚本只负责本地打包。
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    install) cmd_install "$@" ;;
    dev|start) cmd_dev "$@" ;;
    build) cmd_build "$@" ;;
    lint) cmd_lint "$@" ;;
    test) cmd_test "$@" ;;
    unpacked|dir) cmd_unpacked ;;
    setup|installer) cmd_setup ;;
    artifacts|ls) cmd_artifacts ;;
    clean) cmd_clean ;;
    help|-h|--help) cmd_help ;;
    *) err "未知命令：${cmd}"; cmd_help; exit 2 ;;
  esac
}

main "$@"
