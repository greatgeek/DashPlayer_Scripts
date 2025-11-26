#!/usr/bin/env python3
import os
from pathvalidate import sanitize_filename

def safe_filename(filename):
    """安全处理文件名：保留中文，移除非法字符（如 ￡/@）"""
    safe_name = sanitize_filename(filename)
    safe_name = safe_name.replace('￡', '_').replace('@', '_')
    return safe_name

def process_directory():
    """处理当前目录下所有 .mkv 和 .mp4 文件"""
    for filename in os.listdir('.'):
        # 仅处理 .mkv 和 .mp4 文件
        if not filename.lower().endswith(('.mkv', '.mp4')):
            continue
            
        original = filename
        safe = safe_filename(original)
        
        if original == safe:
            print(f"✅ {original} (已安全，无需处理)")
            continue
            
        if os.path.exists(safe):
            print(f"⚠️ 跳过 {original} (目标文件 {safe} 已存在)")
            continue
            
        try:
            os.rename(original, safe)
            print(f"🔄 重命名: {original} → {safe}")
        except Exception as e:
            print(f"❌ 处理失败 {original}: {str(e)}")

if __name__ == "__main__":
    print("="*50)
    print("🚀 正在处理当前目录 .mkv 和 .mp4 文件（保留中文，移除 ￡/@）")
    print("="*50)
    process_directory()
    print("\n✅ 处理完成！所有视频文件已安全重命名")
