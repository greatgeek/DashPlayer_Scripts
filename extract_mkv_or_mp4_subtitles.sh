#!/bin/bash

# 定义帮助信息函数
usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv/.mp4> [文件名2.mkv/.mp4 ...]"
    echo
    echo "检查指定的 .mkv 或 .mp4 文件中是否存在字幕轨道，如果存在则提取为 .srt 格式文件。"
    echo "提取的字幕文件命名格式：<原始文件名>_<语言>_sub<轨道号>.srt"
    echo "（如果无法识别语言，则使用 'unknown' 作为语言标识）"
    echo
    echo "Options:"
    echo "  -h, --help    显示此帮助信息并退出"
    echo
    echo "Examples:"
    echo "  $0 \"my-video.mkv\""
    echo "  $0 \"video1.mp4\" \"video2.mkv\""
}

# 检查 ffmpeg 是否安装
check_dependencies() {
    if ! command -v ffmpeg &> /dev/null; then
        echo "错误：需要安装 ffmpeg 才能运行此脚本。"
        echo "安装方法："
        echo "  - Ubuntu/Debian: sudo apt update && sudo apt install ffmpeg"
        echo "  - macOS (Homebrew): brew install ffmpeg"
        echo "  - Windows: 从 https://ffmpeg.org/download.html 下载并添加到环境变量"
        exit 1
    fi
}

# 提取单个视频文件的字幕（支持 .mkv 和 .mp4）
extract_subtitles() {
    local file="$1"
    # 去掉文件后缀（.mkv 或 .mp4）作为基础文件名
    local base_name="${file%.*}"
    local has_subtitles=false

    echo "=================================================="
    echo "正在处理文件：$file"
    echo "=================================================="

    # 获取所有字幕轨道信息
    local subtitle_info=$(ffmpeg -i "$file" 2>&1 | grep -E 'Stream #0:[0-9]+.*Subtitle')

    # 检查是否有字幕轨道
    if [ -z "$subtitle_info" ]; then
        echo "文件中未检测到字幕轨道。"
        return
    fi

    # 遍历所有字幕轨道
    echo "$subtitle_info" | while read -r line; do
        has_subtitles=true
        
        # 提取轨道索引（例如从 "Stream #0:3" 中提取 "3"）
        local track_index=$(echo "$line" | awk '{print $2}' | cut -d: -f2)
        
        # 提取语言（例如从 "(eng)" 中提取 "eng"）
        local lang=$(echo "$line" | grep -oP '\(\K[^)]+' | head -n1)
        [ -z "$lang" ] && lang="unknown"  # 如果没有语言信息，使用 unknown
        
        # 构建输出文件名
        local output_file="${base_name}_${lang}_sub${track_index}.srt"
        
        echo
        echo "发现字幕轨道 $track_index（语言：$lang），正在提取..."
        echo "输出文件：$output_file"
        
        # 提取字幕（使用 -c:s srt 确保转换为 SRT 格式）
        ffmpeg -i "$file" -map 0:s:"$track_index" -c:s srt -y "$output_file"
        
        # 检查提取结果
        if [ $? -eq 0 ]; then
            echo "字幕提取成功：$output_file"
        else
            echo "警告：字幕轨道 $track_index 提取失败！"
        fi
    done

    if [ "$has_subtitles" = true ]; then
        echo
        echo "文件 $file 的所有字幕轨道处理完成。"
    fi
}

# 主程序入口
main() {
    # 检查依赖
    check_dependencies

    # 处理帮助选项
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi

    # 遍历所有输入文件
    for file in "$@"; do
        # 检查文件是否存在
        if [ ! -f "$file" ]; then
            echo "警告：文件 '$file' 不存在，跳过。"
            continue
        fi

        # 支持 .mkv 和 .mp4 格式
        if [[ "$file" != *.mkv && "$file" != *.mp4 ]]; then
            echo "警告：文件 '$file' 不是 .mkv 或 .mp4 文件，跳过。"
            continue
        fi

        # 提取字幕
        extract_subtitles "$file"
        echo
    done

    echo "所有文件处理完成！"
}

# 启动主程序
main "$@"
