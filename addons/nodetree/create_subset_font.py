#!/usr/bin/env python3
import os
from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter

def create_subset_font(input_font_path, chars_file_path, output_font_path):
    """
    创建只包含指定字符的子集字体文件
    
    Args:
        input_font_path: 输入字体文件路径
        chars_file_path: 包含需要保留的字符的文件路径
        output_font_path: 输出字体文件路径
    """
    # 读取字符文件
    with open(chars_file_path, 'r', encoding='utf-8') as f:
        chinese_chars = f.read().strip()
    
    print(f"需要保留的字符数量: {len(chinese_chars)}")
    
    # 加载原始字体
    font = TTFont(input_font_path)
    
    # 创建子集化器
    subsetter = Subsetter()
    
    # 创建包含所有需要保留字符的Unicode码点列表
    unicodes = [ord(char) for char in chinese_chars]
    
    # 添加一些常用的标点符号和英文字符（可选）
    # 添加空格
    unicodes.append(ord(' '))
    
    # 添加常用标点
    for punct in '.,!?;:()[]{}""''':
        unicodes.append(ord(punct))
    
    # 添加数字
    for digit in '0123456789':
        unicodes.append(ord(digit))
    
    # 添加英文字母
    for letter in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ':
        unicodes.append(ord(letter))
    
    # 添加键盘上能输入的特殊符号
    for symbol in '!@#$%^&*()_+-=[]{}|;:,.<>?/~`':
        unicodes.append(ord(symbol))
    
    # 使用Unicode码点进行子集化
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    
    # 保存新字体
    font.save(output_font_path)
    
    print(f"已创建子集字体文件: {output_font_path}")
    
    # 检查新字体文件大小
    original_size = os.path.getsize(input_font_path)
    new_size = os.path.getsize(output_font_path)
    
    print(f"原始字体大小: {original_size / 1024:.2f} KB")
    print(f"新字体大小: {new_size / 1024:.2f} KB")
    print(f"大小减少: {(1 - new_size / original_size) * 100:.2f}%")

if __name__ == "__main__":
    # 设置文件路径
    input_font_path = "fusion-pixel-12px-proportional-zh_hant.ttf"
    chars_file_path = "chinese_chars.txt"
    output_font_path = "fusion_myminifont.ttf"
    
    # 检查文件是否存在
    if not os.path.exists(input_font_path):
        print(f"错误: 找不到输入字体文件 {input_font_path}")
        exit(1)
    
    if not os.path.exists(chars_file_path):
        print(f"错误: 找不到字符文件 {chars_file_path}")
        exit(1)
    
    # 创建子集字体
    create_subset_font(input_font_path, chars_file_path, output_font_path)
    
    print("\n任务完成!")