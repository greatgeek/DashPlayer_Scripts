#!/bin/bash

# 功能：批量提取 MKV/MP4 中的 ASS 字幕索引，自动转换为 SRT
# 修复点：1. 修正 ffmpeg 命令语法（换行符/引号）；2. 处理特殊文件名；3. 完善成功判断逻辑

usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv/.mp4> [文件名2.mkv/.mp4 ...]"
    echo
    echo "自动提取 ASS 字幕流索引，转换为 SRT 格式"
    echo "输出格式：<原始文件名>.srt"
    echo
    echo "Options:"
    echo "  -h, --help    显示此帮助信息并退出"
}

# 检查依赖（ffprobe、jq、ffmpeg）
check_dependencies() {
    if ! command -v ffprobe &> /dev/null; then
        echo "❌ 错误：未检测到 ffprobe！请安装 FFmpeg（brew install ffmpeg）"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "❌ 错误：未检测到 jq！请安装（brew install jq）"
        exit 1
    fi
    if ! command -v ffmpeg &> /dev/null; then
        echo "❌ 错误：未检测到 ffmpeg！请安装（brew install ffmpeg）"
        exit 1
    fi
}

# 提取单个文件的 ASS 索引并转换（核心修复部分）
extract_ass_and_convert() {
    local file="$1"
    local base_name="${file%.*}"
    # 输出文件用双引号包裹，处理特殊字符（如空格、@、￡等）
    local output_file="${base_name}.srt"

    echo -e "\n=================================================="
    echo "正在处理文件：$file"
    echo "输出 SRT 文件：$output_file"
    echo "=================================================="

    # 1. 提取 ASS 字幕索引（JSON 筛选，确保索引有效）
    local ass_index=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
                      jq -r '.streams[] | select(.codec_name == "ass") | .index')

    if [ -z "$ass_index" ] || [ "$ass_index" = "null" ]; then
        echo "⚠️  未检测到 ASS 字幕流，跳过此文件"
        return 1  # 标记为失败
    fi

    echo "✅ 找到 ASS 字幕流，索引：$ass_index"
    echo "正在转换为 SRT..."

    # 2. 修复 ffmpeg 命令语法：
    #    - 反斜杠后面无空格，直接换行（避免截断）
    #    - 所有路径用双引号包裹（处理特殊字符）
    #    - 保留关键日志（去掉 2>/dev/null，方便排查）
    ffmpeg -i "$file" \
           -map "0:$ass_index" \
           -c:s srt \
           -y \
           "$output_file"

    # 3. 完善成功判断逻辑（必须满足 3 个条件）
    if [ $? -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo "✅ 转换成功：$output_file"
        return 0  # 标记为成功
    else
        echo "❌ 转换失败！"
        [ -f "$output_file" ] && rm -f "$output_file"  # 清理无效文件
        return 1  # 标记为失败
    fi
}

# 主程序入口
main() {
    check_dependencies

    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi

    local total_files=$#
    local success_count=0
    local fail_count=0

    echo "📋 开始处理 $total_files 个文件..."

    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo -e "\n⚠️  文件 '$file' 不存在，跳过"
            ((fail_count++))
            continue
        fi

        if [[ "$file" != *.mkv && "$file" != *.mp4 ]]; then
            echo -e "\n⚠️  文件 '$file' 不是 MKV/MP4 格式，跳过"
            ((fail_count++))
            continue
        fi

        # 根据函数返回值计数
        if extract_ass_and_convert "$file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # 输出正确的总结
    echo -e "\n=================================================="
    echo "📊 处理总结："
    echo "总文件数：$total_files"
    echo "成功转换：$success_count"
    echo "跳过/失败：$fail_count"
    echo "=================================================="
}

main "$@"
