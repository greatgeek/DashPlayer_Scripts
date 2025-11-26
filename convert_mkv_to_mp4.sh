#!/bin/bash

# 定义帮助信息函数
usage() {
    echo "Usage: $0 [-h|--help] <文件名1.mkv> [文件名2.mkv ...]"
    echo
    echo "将指定的 .mkv 文件转换为 .mp4 文件（不包含字幕）。"
    echo "转换后的文件名格式为：<原始文件名>-convert.mp4"
    echo
    echo "Options:"
    echo "  -h, --help    显示此帮助信息并退出"
    echo
    echo "Examples:"
    echo "  $0 \"my-video.mkv\""
    echo "  $0 \"video1.mkv\" \"video2.mkv\""
}

# 检查是否提供了参数
if [ $# -eq 0 ]; then
    echo "错误：请提供至少一个 .mkv 文件名作为参数。"
    echo
    usage
    exit 1
fi

# 检查第一个参数是否为帮助选项
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# 遍历所有传入的命令行参数
for file in "$@"; do
    # 检查文件是否存在且为 .mkv 文件
    if [ ! -f "$file" ]; then
        echo "文件 '$file' 不存在，跳过。"
        continue
    fi

    if [[ "$file" != *.mkv ]]; then
        echo "文件 '$file' 不是 .mkv 文件，跳过。"
        continue
    fi

    # 将文件名中的 .mkv 后缀替换为 -convert.mp4
    output="${file%.mkv}-convert.mp4"
    
    # 打印转换信息
    echo "=================================================="
    echo "正在转换：$file"
    echo "输出文件：$output"
    echo "=================================================="
    
    # 执行 FFmpeg 转换命令
    ffmpeg -i "$file" -c:v copy -c:a copy -sn "$output"
    
    # 检查上一条命令的执行结果
    if [ $? -eq 0 ]; then
        echo "转换成功：$output"
    else
        echo "转换失败：$file"
    fi
done

echo "所有指定文件处理完成！"
