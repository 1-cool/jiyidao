#!/bin/bash

# NCNN 模型文件下载脚本
# 使用方法：
#   1. 直接运行：./download_models.sh
#   2. 使用代理：https_proxy=http://your-proxy:port ./download_models.sh

set -e

# 模型文件下载地址
BASE_URL="https://raw.githubusercontent.com/Saifulkamil/Flutter-Paddle-OCR-with-NCNN/main/example/assets"

# 目标目录
TARGET_DIR="$(dirname "$0")/../assets/ocr"

# 创建目标目录
mkdir -p "$TARGET_DIR"

echo "开始下载 NCNN 模型文件..."
echo "目标目录: $TARGET_DIR"
echo ""

# 下载文件列表
declare -A FILES=(
    ["PP_OCRv5_mobile_det.ncnn.bin"]="det.ncnn.bin"
    ["PP_OCRv5_mobile_det.ncnn.param"]="det.ncnn.param"
    ["PP_OCRv5_mobile_rec.ncnn.bin"]="rec.ncnn.bin"
    ["PP_OCRv5_mobile_rec.ncnn.param"]="rec.ncnn.param"
)

# 下载每个文件
for src_name in "${!FILES[@]}"; do
    dest_name="${FILES[$src_name]}"
    url="$BASE_URL/$src_name"
    dest_path="$TARGET_DIR/$dest_name"
    
    echo "下载: $src_name"
    echo "  → $dest_name"
    
    if [ -f "$dest_path" ]; then
        echo "  ✓ 文件已存在，跳过"
    else
        curl -L -o "$dest_path" "$url" --progress-bar || {
            echo "  ✗ 下载失败！"
            echo "  提示：如果在国内，请使用代理："
            echo "    https_proxy=http://your-proxy:port ./download_models.sh"
            exit 1
        }
        echo "  ✓ 下载完成"
    fi
    echo ""
done

# 检查文件大小
echo "检查文件大小..."
declare -A EXPECTED_SIZES=(
    ["det.ncnn.bin"]="2301k"
    ["det.ncnn.param"]="24k"
    ["rec.ncnn.bin"]="8200k"
    ["rec.ncnn.param"]="20k"
)

for file in "${!EXPECTED_SIZES[@]}"; do
    file_path="$TARGET_DIR/$file"
    if [ -f "$file_path" ]; then
        size=$(du -h "$file_path" | cut -f1)
        echo "  $file: $size"
    fi
done

echo ""
echo "✓ 所有模型文件下载完成！"
echo ""
echo "下一步："
echo "  cd .."
echo "  flutter pub get"
echo "  flutter run"
