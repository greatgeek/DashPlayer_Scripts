#!/bin/bash

# 功能：批量提取 MKV/MP4 中的字幕（支持 subrip/ass），自动转换为 SRT
# 修复点：1. 修复FFmpeg字幕流索引映射问题；2. 适配subrip/ass字幕；3. 处理SDH标签；4. 100%兼容特殊文件名

usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv/.mp4> [文件名2.mkv/.mp4 ...]"
    echo
    echo "自动提取所有字幕流（subrip/ass），转换为 SRT 格式"
    echo "输出格式：<原始文件名>_SDH.srt 或 <原始文件名>.srt"
    echo
    echo "Options:"
    echo "  -h, --help    显示此帮助信息并退出"
}

# 检查依赖（ffprobe、jq、ffmpeg）
check_dependencies() {
    for cmd in ffprobe jq ffmpeg; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ 错误：未检测到 $cmd！请安装 FFmpeg（brew install ffmpeg）"
            exit 1
        fi
    done
}

# 提取单个文件的所有字幕流并转换（核心修复）
extract_subtitles() {
    local file="$1"
    local base_name="${file%.*}"
    echo -e "\n=================================================="
    echo "正在处理文件：$file"
    echo "=================================================="

    # 获取所有匹配的字幕流索引（按全局索引排序）
    local subtitle_streams=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
        jq -r '.streams[] | select(.codec_type == "subtitle" and (.codec_name == "subrip" or .codec_name == "ass")) | .index' | sort -n)

    if [ -z "$subtitle_streams" ]; then
        echo "⚠️  未检测到字幕流，跳过此文件"
        return 1
    fi

    # 按顺序处理每个字幕流（分配正确的字幕类型索引）
    local count=0
    for idx in $subtitle_streams; do
        # 获取字幕标题（SDH 标识）
        local title=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].tags.title // \"\"")
        
        # 构建输出文件名
        local output_file
        if [ -n "$title" ] && [ "$title" = "SDH" ]; then
            output_file="${base_name}_SDH.srt"
        else
            output_file="${base_name}.srt"
        fi

        echo "  → 提取字幕流（全局索引 $idx, 类型索引 $count）标题: $title → $output_file"
        ffmpeg -i "$file" -map "0:s:$count" -c:s srt -y "$output_file"

        # 验证转换结果
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
