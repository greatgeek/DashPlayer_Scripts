#!/bin/bash

# 功能：批量提取 MKV/MP4 中英字幕（保留完整标题），用标题区分文件名
# 特性：1. 保留标题原始内容（含中文/符号） 2. 自动处理文件系统禁止字符 3. ASS 自动转 SRT

usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv/.mp4> [文件名2.mkv/.mp4 ...]"
    echo
    echo "自动提取中文字幕（language=chi）和英文字幕（language=eng）"
    echo "文件名格式：原始文件名_语言_标题.srt（保留标题原始内容）"
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

    # ✅ 同时提取 chi/eng 字幕流
    local subtitle_streams=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
        jq -r '.streams[] | select(.codec_type == "subtitle" and (.tags.language == "chi" or .tags.language == "eng")) | .index' | sort -n)

    if [ -z "$subtitle_streams" ]; then
        echo "⚠️  未检测到中文字幕（chi）或英文字幕（eng），跳过此文件"
        return 1
    fi

    local total_success=0
    local chi_count=0
    local eng_count=0

    for idx in $subtitle_streams; do
        local codec_name=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].codec_name")
        local language=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].tags.language // \"unknown\"")
        local title=$(ffprobe -v quiet -print_format json -show_streams "$file" | \
            jq -r ".streams[$idx].tags.title // \"\"")

        # ✅ 关键修改：保留标题完整内容（仅处理文件系统禁止字符）
        local title_clean
        if [ -z "$title" ]; then
            title_clean="default"
        else
            # 替换Windows文件系统禁止字符（/ \ : * ? " < > |）为下划线
            title_clean=$(echo "$title" | sed 's/[\\/:*?"<>|]/_/g')
            # 合并连续下划线，去掉开头结尾下划线
            title_clean=$(echo "$title_clean" | tr -s '_' | sed 's/^_//' | sed 's/_$//')
            # 如果清理后为空，用default
            if [ -z "$title_clean" ]; then
                title_clean="default"
            fi
        fi

        # 生成完整标题的文件名
        local output_file="${base_name}_${language}_${title_clean}.srt"

        echo "  → 提取字幕流（索引 $idx）语言: $language, 标题: $title → $output_file"

        # ✅ 处理不同字幕格式
        if [ "$codec_name" = "subrip" ]; then
            ffmpeg -i "$file" -map "0:$idx" -c:s copy -y "$output_file"
        elif [ "$codec_name" = "ass" ]; then
            ffmpeg -i "$file" -map "0:$idx" -c:s srt -y "$output_file"
        elif [ "$codec_name" = "hdmv_pgs_subtitle" ]; then
            echo "    ⚠️  跳过不支持的字幕类型: PGS (hdmv_pgs_subtitle)"
            continue
        else
            echo "    ⚠️  跳过不支持的字幕类型: $codec_name"
            continue
        fi

        if [ $? -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
            echo "    ✅ 成功: $output_file"
            total_success=$((total_success + 1))
            if [ "$language" = "chi" ]; then
                chi_count=$((chi_count + 1))
            elif [ "$language" = "eng" ]; then
                eng_count=$((eng_count + 1))
            fi
        else
            echo "    ❌ 失败: $output_file"
            [ -f "$output_file" ] && rm -f "$output_file"
        fi
    done

    if [ $total_success -gt 0 ]; then
        echo "    📦 共提取：中文字幕 $chi_count 个，英文字幕 $eng_count 个"
        return 0
    else
        echo "    ❌ 未成功提取任何字幕"
        return 1
    fi
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
