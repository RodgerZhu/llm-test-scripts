#!/bin/bash

# Strict mode settings
set -ex

# 默认结果目录（可通过命令行覆盖）
DEFAULT_RESULT_DIR="/home/"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --result-dir)
      RESULT_DIR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 设置最终结果目录（优先使用命令行参数，否则用默认值）
RESULT_DIR="${RESULT_DIR:-$DEFAULT_RESULT_DIR}"

# 其他固定配置
MODEL_PATH="/home/deepseek-ai/"
PORT=8102
DATASET_NAME="sharegpt"
DATASET_PATH="/home/deepseek-ai/ShareGPT_V3_unfiltered_cleaned_split.json"
LOG_FILE="${RESULT_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).log"

# 确保结果目录存在
mkdir -p "${RESULT_DIR}"

# Parameter Matrix
NUM_PROMPTS=(10 50  100 200 400 500 1000  1500 2000)
INPUT_LENS=(1024 )
OUTPUT_LENS=(512)
CONCURRENCIES=(1)

# Execute single test case
run_benchmark() {
    local num_prompts=$1
    local input_len=$2
    local output_len=$3
    local concurrency=$4

    local result_file="${RESULT_DIR}/${num_prompts}-${input_len}-${output_len}-${concurrency}.json"

    echo "[$(date +%T)] Starting test: prompts=${num_prompts} input=${input_len} output=${output_len} concurrency=${concurrency}"

    python3 benchmark_serving.py \
        --backend vllm \
        --model "${MODEL_PATH}" \
        --port ${PORT} \
        --endpoint /v1/completions \
        --dataset-name "${DATASET_NAME}" \
        --dataset-path "${DATASET_PATH}" \
        --max-concurrency ${concurrency} \
        --random-input-len ${input_len} \
        --random-output-len ${output_len} \
        --num-prompts ${num_prompts} \
        --save-result \
        --result-dir "${RESULT_DIR}" \
        --result-filename "${num_prompts}-${input_len}-${output_len}-${concurrency}.json"

    local status=${PIPESTATUS[0]}
    if [ $status -ne 0 ]; then
        echo "[$(date +%T)] Test failed: prompts=${num_prompts} input=${input_len} output=${output_len} concurrency=${concurrency} code=${status}"
        return 1
    fi

    echo "[$(date +%T)] Completed test: prompts=${num_prompts} input=${input_len} output=${output_len} concurrency=${concurrency}"
    return 0
}

# Main execution flow
main() {
    total_cases=$((${#NUM_PROMPTS[@]} * ${#INPUT_LENS[@]} * ${#OUTPUT_LENS[@]} * ${#CONCURRENCIES[@]}))
    current_case=0

    for num_prompts in "${NUM_PROMPTS[@]}"; do
        for input_len in "${INPUT_LENS[@]}"; do
            for output_len in "${OUTPUT_LENS[@]}"; do
                for concurrency in "${CONCURRENCIES[@]}"; do
                    current_case=$((current_case + 1))
                    progress=$((current_case * 100 / total_cases))
                    echo "[Progress: ${progress}%] Case ${current_case}/${total_cases}"

                    if ! run_benchmark $num_prompts $input_len $output_len $concurrency; then
                        echo "Error detected, waiting 30 seconds before continuing..."
                        sleep 30
                    fi
                done
            done
        done
    done

    echo "==== Benchmark Completed: $(date) ===="
    echo "最终结果目录: ${RESULT_DIR}"
}

# Execute main program
main "$@" 2>&1 | tee -a "${LOG_FILE}"
