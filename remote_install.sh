#!/bin/sh
# TaiChi CPE 远程安装脚本
# 用法: sh remote_install.sh [token]
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN="${1:-}"
APP_DIR="/home/root/TaiChi_CPE"
STAGING="/tmp/ota_staging"
JSON_URL="https://capfyun.github.io/taichi_cpe.json"
JSON_FILE="/tmp/taichi_cpe.json"

echo "=== TaiChi CPE Remote Install ==="

# 从远程JSON获取ota_url
echo "正在获取配置信息: $JSON_URL"
if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate -q -O "$JSON_FILE" "$JSON_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -kso "$JSON_FILE" "$JSON_URL"
else
    echo "ERROR: 未找到 wget 或 curl，无法获取配置信息"
    exit 1
fi

if [ ! -f "$JSON_FILE" ] || [ ! -s "$JSON_FILE" ]; then
    echo "ERROR: 无法获取配置信息，请检查网络连接"
    rm -f "$JSON_FILE"
    exit 1
fi

# 解析ota_url（兼容无jq的环境，使用grep+sed）
OTA_URL=""
if command -v jq >/dev/null 2>&1; then
    OTA_URL=$(jq -r '.ota_url' "$JSON_FILE" 2>/dev/null)
else
    OTA_URL=$(grep -o '"ota_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" | sed 's/.*"ota_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

if [ -z "$OTA_URL" ]; then
    echo "ERROR: 无法从配置中解析 ota_url"
    echo "JSON内容:"
    cat "$JSON_FILE"
    rm -f "$JSON_FILE"
    exit 1
fi

# 解析tools_url（可选）
TOOLS_URL=""
if command -v jq >/dev/null 2>&1; then
    TOOLS_URL=$(jq -r '.tools_url' "$JSON_FILE" 2>/dev/null)
else
    TOOLS_URL=$(grep -o '"tools_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" | sed 's/.*"tools_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

# 解析version（可选，用于显示）
VERSION=""
if command -v jq >/dev/null 2>&1; then
    VERSION=$(jq -r '.version' "$JSON_FILE" 2>/dev/null)
else
    VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

echo "版本: ${VERSION:-unknown}"
echo "OTA URL: $OTA_URL"
[ -n "$TOOLS_URL" ] && echo "Tools URL: $TOOLS_URL"

# 清理JSON临时文件
rm -f "$JSON_FILE"

# 下载OTA包
mkdir -p "$STAGING"
if [ -n "$TOKEN" ]; then
    curl -sL -o "$STAGING/ota.tar.gz" "${OTA_URL}?token=${TOKEN}"
else
    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -q -O "$STAGING/ota.tar.gz" "$OTA_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -kso "$STAGING/ota.tar.gz" "$OTA_URL"
    fi
fi

if [ ! -f "$STAGING/ota.tar.gz" ] || [ ! -s "$STAGING/ota.tar.gz" ]; then
    echo "ERROR: 下载OTA包失败"
    rm -rf "$STAGING"
    exit 1
fi

# 解压
cd "$STAGING"
tar xzf ota.tar.gz

# 使用一键部署方式安装（调用install.sh）
if [ -f "$STAGING/install.sh" ]; then
    sh "$STAGING/install.sh"
elif [ -f "$STAGING/home/root/install.sh" ]; then
    sh "$STAGING/home/root/install.sh"
else
    echo "ERROR: install.sh not found in OTA package"
    rm -rf "$STAGING"
    exit 1
fi

# 清理已下载文件
rm -rf "$STAGING"
echo "=== Remote Install Complete ==="
