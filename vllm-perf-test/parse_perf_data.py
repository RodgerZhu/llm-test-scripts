import json
import os
import re
import csv
import argparse
from tabulate import tabulate

# 配置参数
TARGET_FIELDS = [
    "max_concurrency", "total_token_throughput",
    "output_throughput", "mean_ttft_ms", "mean_tpot_ms", "median_tpot_ms", "mean_itl_ms", "num_prompts","input_len", "output_len"
]
TABLE_FORMAT = "grid"

def parse_filename(filename):
    """从文件名提取前两个连字符分隔的数字"""
    filename_without_ext = os.path.splitext(filename)[0]
    parts = filename_without_ext.split('-')

    num_prompts, input_len, output_len = "N/A", "N/A", "N/A"
    if len(parts) >= 1:
        try:
            num_prompts = int(parts[0])
        except ValueError:
            pass
    if len(parts) >= 2:
        try:
            input_len = int(parts[1])
        except ValueError:
            pass
    if len(parts) >= 3:
        try:
            output_len = int(parts[2])
        except ValueError:
            pass
    return num_prompts,input_len, output_len

def format_value(value):
    """数值格式化"""
    if isinstance(value, (int, float)):
        return round(value, 2) if isinstance(value, float) else value
    return value

def process_file(filepath):
    """处理单个JSON文件"""
    try:
        filename = os.path.basename(filepath)
        num_prompts, input_len, output_len = parse_filename(filename)
        with open(filepath, 'r') as f:
            data = json.load(f)

        processed_data = {
            **{k: format_value(data.get(k, "N/A")) for k in TARGET_FIELDS if k not in ["num_prompts", "input_len", "output_len"]},
            "num_prompts": num_prompts,
            "input_len": input_len,
            "output_len": output_len
        }
        return processed_data
    except Exception as e:
        print(f"处理文件 {filename} 出错: {str(e)}")
        return None

def generate_table(data):
    """生成文本表格"""
    headers = []
    for field in TARGET_FIELDS:
        if field == "num_prompts":
            headers.append("num_prompts")
        elif field == "input_len":
            headers.append("Input (m)")
        elif field == "output_len":
            headers.append("Output (m)")
        else:
            header = field.replace("_", " ").title().replace(" Ms", " (ms)")
            headers.append(header)

    return tabulate(
        [list(entry.values()) for entry in data],
        headers=headers,
        tablefmt=TABLE_FORMAT,
        numalign="right",
        floatfmt=".2f"
    )

def save_report(content, filename):
    """保存文本报告"""
    try:
        with open(filename, 'w') as f:
            f.write(content)
        return True
    except IOError as e:
        print(f"文本报告保存失败: {str(e)}")
        return False

def save_to_csv(data, filename):
    """保存数据到CSV文件"""
    try:
        csv_headers = [
            "Max Concurrency", "Total Token Throughput",
            "Output Throughput", "Mean TTFT (ms)",
            "Mean TPOT (ms)", "Median TPOT (ms)","mean_itl_ms","num_prompts","input_len", "output_len"
        ]

        with open(filename, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(csv_headers)
            for entry in data:
                row = [entry[k] for k in TARGET_FIELDS]
                writer.writerow(row)
        return True
    except Exception as e:
        print(f"CSV文件保存失败: {str(e)}")
        return False

def main():
    # 解析命令行参数
    parser = argparse.ArgumentParser(description='生成性能报告')
    parser.add_argument('--json_dir', required=True, help='包含JSON文件的目录路径')
    args = parser.parse_args()

    # 动态生成输出文件名
    base_name = os.path.basename(os.path.normpath(args.json_dir))
    output_txt = f"{base_name}.txt"
    output_csv = f"{base_name}.csv"

    # 检查目录存在性
    if not os.path.exists(args.json_dir):
        print(f"目录不存在: {args.json_dir}")
        return

    # 处理所有JSON文件
    json_files = [
        os.path.join(args.json_dir, f)
        for f in os.listdir(args.json_dir)
        if f.endswith(".json")
    ]

    processed_data = []
    for filepath in json_files:
        if (result := process_file(filepath)) is not None:
            processed_data.append(result)

    if not processed_data:
        print("没有可用的JSON数据")
        return

    # 生成并保存报告
    print("\n性能指标汇总：")
    table_content = generate_table(processed_data)
    print(table_content)
    save_report(table_content, output_txt)

    if save_to_csv(processed_data, output_csv):
        print(f"\n结构化数据已保存至: {os.path.abspath(output_csv)}")

if __name__ == "__main__":
    main()
