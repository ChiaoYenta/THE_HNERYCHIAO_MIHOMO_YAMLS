#!/usr/bin/env bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检测 Hash 工具
if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
else
  echo -e "${RED}❌ Error: sha256sum not found${NC}"
  exit 1
fi

# 2. 单文件下载与 Hash 对比函数
fetch_and_hash() {
  local url="$1"
  local out="$2"

  # 忽略无效行
  [[ -z "$url" || -z "$out" || "$url" =~ ^# ]] && return 0

  mkdir -p "$(dirname "$out")"
  local tmp="${out}.tmp.$$"

  # 下载 (允许重试 2 次，最大 15 秒超时)
  if ! curl -fsSL --retry 2 --retry-connrefused --connect-timeout 15 "$url" -o "$tmp"; then
    echo -e "${RED}❌ Download Failed:${NC} $url"
    rm -f "$tmp"
    return 1
  fi

  # 检查目标文件是否存在以对比 Hash
  if [[ -f "$out" ]]; then
    local old_hash new_hash
    old_hash="$($HASH_CMD "$out" | awk '{print $1}')"
    new_hash="$($HASH_CMD "$tmp" | awk '{print $1}')"

    if [[ "$old_hash" == "$new_hash" ]]; then
      rm -f "$tmp"
      echo -e "${BLUE}⏭️  Skipped (No Change):${NC} $out"
      return 0
    fi
  fi

  # 移动新文件
  mv "$tmp" "$out"
  echo -e "${GREEN}✅ Updated:${NC} $out"
}

# 3. 并行调度器
run_parallel_tasks() {
  local tasks="$1"
  local max_jobs="${2:-5}" # 默认 5 并发
  local pids=()
  local i=0

  echo -e "${YELLOW}🚀 Starting batch download ($max_jobs threads)...${NC}"

  # 逐行读取任务
  while IFS="|" read -r url out; do
    # 忽略空行
    [[ -z "$url" || "$url" =~ ^# ]] && continue

    # 后台执行
    fetch_and_hash "$url" "$out" &
    pids+=($!)
    
    # 简单的批次控制：每启动 N 个任务就等待这一批完成
    ((i++))
    if (( i % max_jobs == 0 )); then
      wait
    fi
  done <<< "$tasks"

  # 等待剩余任务
  wait
  echo -e "${YELLOW}🏁 Batch processing complete.${NC}"
}
