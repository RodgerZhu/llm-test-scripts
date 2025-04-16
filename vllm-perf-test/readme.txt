How to:
1. Run the benchmark script:

```
cd vllm/benchmarks
./run_vllm_benchmark_serving.sh
```

2. Parse the test data:

```
cd /home/deepseek-ai/results-0416-1
python3 parse_perf_data.py --json_dir results-0416-1 
```

