#!/bin/bash

# 功能：批量提取 MKV/MP4 字幕（精准区分 subrip/ass，完美处理特殊字符）
# 修复点：1. 统一使用全局流索引（0:index）；2. 修复参数顺序；3. 100%兼容 Mac 特殊字符

usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv/.mp4> [文件名2.mkv/.mp4 ...]"
    echo
    echo "自动提取字幕流（subrip/ass），分别转换为 SRT 格式"
    echo "输出格式：<原始文件名>_SDH.srt 或 <原始文件名>.srt"
    echo
    echo "Options:"
    echo "  -h, --help    显示此帮助信息并退出"
}

check_dependencies() {
    for cmd in ffprobe jq ffmpeg; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ 错误：未检测到 $cmd！请安装 FFmpeg（brew install ffmpeg）"
            exit 1
        fi
    done
}

extract_subtitles() {
    local file="$1"
    local base_name="${file%.*}"
    echo -e "\n=================================================="
    echo "正在处理文件：$file"
    echo "=================================================="

    # 获取所有字幕流的全局索引（直接使用 FFmpeg 的全局索引）
    local subtitle_streams=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
        jq -r '.streams[] | select(.codec_type == "subtitle") | .index' | sort -n)

    if [ -z "$subtitle_streams" ]; then
        echo "⚠️  未检测到字幕流，跳过此文件"
        return 1
    fi

    local count=0
    for idx in $subtitle_streams; do
        # 通过全局索引获取字幕类型
        local codec_name=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].codec_name")
        local title=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].tags.title // \"\"")

        # 生成输出文件名（逻辑不变）
        local output_file
        if [ -n "$title" ] && [ "$title" = "SDH" ]; then
            output_file="${base_name}_SDH.srt"
        else
            output_file="${base_name}.srt"
        fi

        # ✅ 关键修复：统一使用全局索引（0:$idx）！
        echo "  → 提取字幕流（全局索引 $idx, 字幕顺序 $count）标题: $title, 类型: $codec_name → $output_file"

        if [ "$codec_name" = "subrip" ]; then
            # SRT：直接复制（保留原始编码）
            ffmpeg -i "$file" -map "0:$idx" -c:s copy -y "$output_file"
        elif [ "$codec_name" = "ass" ]; then
            # ASS：转换为 SRT（强制 UTF-8 编码）
            ffmpeg -i "$file" -map "0:$idx" -c:s srt -y "$output_file"
        else
            echo "    ⚠️  跳过不支持的字幕类型: $codec_name"
            continue
        fi

        # 成功判断（逻辑不变）
        if [ $? -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
            echo "    ✅ 成功: $output_file"
        else
            echo "    ❌ 失败: $output_file"
            [ -f "$output_file" ] && rm -f "$output_file"
            return 1
        fi
        count=$((count + 1))
    done
    return 0
}

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

        if [[ ! "$file" =~ \.(mkv|mp4)$ ]]; then
            echo -e "\n⚠️  文件 '$file' 不是 MKV/MP4 格式，跳过"
            ((fail_count++))
            continue
        fi

        if extract_subtitles "$file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    echo -e "\n=================================================="
    echo "📊 处理总结："
    echo "总文件数：$total_files"
    echo "成功转换：$success_count"
    echo "失败/跳过：$fail_count"
    echo "=================================================="
}

main "$@"
