#!/bin/bash

# Strict mode settings
set -ex

# Configuration Parameters
MODEL_PATH="/home/deepseek-ai/"
PORT=8102
DATASET_NAME="sharegpt"
DATASET_PATH="/home/deepseek-ai/ShareGPT_V3_unfiltered_cleaned_split.json"
RESULT_DIR="/home/deepseek-ai/results-0416-1"
LOG_FILE="${RESULT_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).log"

# Parameter Matrix
INPUT_LENS=(8192 16384) # (512 1024 2048 4096)  #(128 4096  )
OUTPUT_LENS=(128 512 1024) #(1024)
CONCURRENCIES=(1) # (1 2 4 8 16 32) #(1 2 4 8 16 32 64 80)

# Execute single test case
run_benchmark() {
    local input_len=$1
    local output_len=$2
    local concurrency=$3

    local result_file="${RESULT_DIR}/${input_len}-${output_len}-${concurrency}.json"

    echo "[$(date +%T)] Starting test: input=${input_len} output=${output_len} concurrency=${concurrency}"

    # Execute benchmark command
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
        --num-prompts 100 \
        --save-result \
        --result-dir "${RESULT_DIR}" \
        --result-filename "${input_len}-${output_len}-${concurrency}.json"

    local status=${PIPESTATUS[0]}
    if [ $status -ne 0 ]; then
        echo "[$(date +%T)] Test failed: input=${input_len} output=${output_len} concurrency=${concurrency} code=${status}"
        return 1
    fi

    echo "[$(date +%T)] Completed test: input=${input_len} output=${output_len} concurrency=${concurrency}"
    return 0
}

# Main execution flow
main() {
    # init_environment

    # Service warmup
    #echo "[INFO] Warming up model service..." | tee -a "${LOG_FILE}"
    #curl -s -X POST "http://localhost:${PORT}/v1/completions" \
    #    -H "Content-Type: application/json" \
    #    -d '{"prompt":"warmup", "max_tokens":5}' >/dev/null 2>&1 || true

    # Iterate through parameter combinations
    total_cases=$((${#INPUT_LENS[@]} * ${#OUTPUT_LENS[@]} * ${#CONCURRENCIES[@]}))
    current_case=0

    for input_len in "${INPUT_LENS[@]}"; do
        for output_len in "${OUTPUT_LENS[@]}"; do
            for concurrency in "${CONCURRENCIES[@]}"; do
                # Calculate progress
                # Execute test with cooldown
                if ! run_benchmark $input_len $output_len $concurrency; then
                    echo "Error detected, waiting 30 seconds before continuing..."
                    sleep 30
                fi

            done
        done
    done

    echo "==== Benchmark Completed: $(date) ===="
}

# Execute main program
main
