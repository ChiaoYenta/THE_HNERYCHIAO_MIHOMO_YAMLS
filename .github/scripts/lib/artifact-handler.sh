#!/usr/bin/env bash
# artifact-handler.sh - 产物处理脚本（全平台版）
# 用途：统一处理构建产物（压缩、UPX准备）

set -euo pipefail

# 参数检查
if [[ $# -ne 6 ]]; then
    echo "用法: $0 <input_file> <project> <variant> <platform> <arch> <output_dir>"
    exit 1
fi

INPUT_FILE="$1"
PROJECT="$2"
VARIANT="$3"
PLATFORM="$4"
ARCH="$5"
OUTPUT_DIR="$6"

# 检查输入文件
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "错误: 输入文件不存在: $INPUT_FILE"
    echo "当前目录: $(pwd)"
    ls -la
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 构建基础文件名
BASE_NAME="${PROJECT}-${VARIANT}-${PLATFORM}-${ARCH}"

if [[ "$INPUT_FILE" == *.exe ]]; then
    # Windows: 直接复制exe
    cp "$INPUT_FILE" "${OUTPUT_DIR}/${BASE_NAME}.exe"
    echo "已复制Windows产物: ${OUTPUT_DIR}/${BASE_NAME}.exe"
else
    # 非Windows: 创建tar.gz归档
    TMP_DIR=$(mktemp -d)
    cp "$INPUT_FILE" "${TMP_DIR}/CrashCore"
    chmod +x "${TMP_DIR}/CrashCore"
    
    tar --no-same-owner -czf "${OUTPUT_DIR}/${BASE_NAME}.tar.gz" -C "$TMP_DIR" CrashCore
    echo "已创建归档: ${OUTPUT_DIR}/${BASE_NAME}.tar.gz"
    
    # 准备UPX文件（仅Linux和Android支持UPX）
    if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "android" ]]; then
        cp "$INPUT_FILE" "${OUTPUT_DIR}/${BASE_NAME}.upx"
        chmod +x "${OUTPUT_DIR}/${BASE_NAME}.upx"
        echo "已准备UPX文件: ${OUTPUT_DIR}/${BASE_NAME}.upx"
    fi
    
    rm -rf "$TMP_DIR"
fi

echo "产物处理完成: ${BASE_NAME}"
