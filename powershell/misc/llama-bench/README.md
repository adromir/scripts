# 🦙 llama.cpp Build Benchmark Suite

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![UI](https://img.shields.io/badge/UI-WPF%20XAML-purple.svg)](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/)
[![llama.cpp](https://img.shields.io/badge/llama.cpp-Compatible-ff69b4.svg)](https://github.com/ggerganov/llama.cpp)
[![i18n](https://img.shields.io/badge/Languages-English%20%7C%20Deutsch-orange.svg)](#-multilingual-support)
[![Author](https://img.shields.io/badge/Author-Adromir-informational.svg)](https://github.com/adromir)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**llama.cpp Build Benchmark Suite** is a modern, standalone WPF PowerShell GUI tool engineered to run automated, real-world comparative performance benchmarks across multiple [llama.cpp](https://github.com/ggerganov/llama.cpp) builds (`llama-cli.exe`).

Whether comparing different compiler backends (CUDA vs. Vulkan vs. OpenCL vs. CPU AVX2/AVX512), evaluating custom compiler optimization flags, or tracking performance regressions between llama.cpp releases, this utility provides reproducible metrics and generates interactive visual HTML benchmark reports.

---

## 🌟 Why Use This Tool?

Manually running `llama-cli.exe` commands with identical prompts, context lengths, and parameter flags while parsing stdout/stderr timing logs is tedious and prone to inconsistent test conditions.

**llama.cpp Build Benchmark Suite** automates this workflow end-to-end: it standardizes test execution across multiple executables and outputs side-by-side comparison charts with cold model load times, prompt evaluation throughput, and token generation speed.

### Key Advantages

* 🎯 **Side-by-Side Multi-Build Testing:** Add multiple `llama-cli.exe` binaries and benchmark them sequentially under identical hardware and parameter constraints.
* 📊 **Interactive Offline HTML Reports:** Generates standalone, responsive HTML reports featuring [Chart.js](https://www.chartjs.org/) bar charts and granular timing breakdown tables. Auto-downloads Chart.js locally (`assets/`) for completely offline viewing.
* 🧪 **Standardized Real-World Scenarios:**
  * **Scenario 1 (Short Query):** Measures first-token responsiveness and low-latency throughput (64 output tokens).
  * **Scenario 2 (Code & Logic):** Evaluates balanced multi-step inference throughput (128 output tokens).
  * **Scenario 3 (Long Context Prefill):** Tests memory bandwidth and prompt ingestion speed under complex multi-paragraph context.
* 📈 **Comprehensive Metric Extraction:** Parses precise engine metrics:
  * **Cold Model Load Time** (ms)
  * **Prompt Processing Speed** (tokens/second)
  * **Token Generation Speed** (tokens/second)
* 🎨 **Modern Dark WPF GUI:** Built with an eye-friendly Catppuccin-inspired dark theme, real-time progress bar, responsive background dispatching, and live execution logging.
* 🌐 **Live Multilingual UI:** Seamless instant switching between **English** and **German** interface text.
* ⚙️ **Flexible Parameter Tuning:** Full control over CPU threads (`-t`), GPU offload layers (`-ngl`), context size (`-c`), and custom Jinja chat template paths (`--chat-template-file`).

---

## 📸 Interface Preview

```text
+-----------------------------------------------------------------------------------------------+
| 🦙 llama.cpp Build Benchmark Suite                                          Language: [ EN v ] |
+-----------------------------------------------------------------------------------------------+
| [ Model & Parameters ]                                                                        |
|  GGUF Model Path: [ C:\models\Llama-3.1-8B-Instruct.Q4_K_M.gguf          ] [ Browse... ]     |
|  Threads (-t): [ 8 ]      GPU Layers (-ngl): [ 99 ]      Context Size (-c): [ 4096 ]          |
|  Chat Template: [                                                         ] [ Browse... ]     |
+-----------------------------------------------------------------------------------------------+
| [ llama.cpp Executables ]                     | [ Test Suite Scenarios ]                       |
| +-------------------------------------------+ | [x] Scenario 1: Short Query (Quick Q&A)       |
| | C:\builds\llama-cuda-12.4\llama-cli.exe   | | [x] Scenario 2: Code & Logic (Balanced)       |
| | C:\builds\llama-vulkan\llama-cli.exe      | | [x] Scenario 3: Long Context (Prefill)        |
| | C:\builds\llama-cpu-avx2\llama-cli.exe    | |                                               |
| +-------------------------------------------+ | Scenarios evaluate:                           |
| [ Add Build... ] [ Remove Selected ] [ Clear ]| • Prompt evaluation throughput (tokens/sec)   |
|                                               | • Generation throughput (tokens/sec)          |
|                                               | • Cold model load time (milliseconds)         |
+-----------------------------------------------------------------------------------------------+
| [ Start Benchmark ]   [ Open HTML Report ]   [========================>              ] 66%    |
+-----------------------------------------------------------------------------------------------+
| [ Execution Log ]                                                                             |
| [14:20:10] Running benchmark on: llama-cuda-12.4 / Scenario 1...                              |
| [14:20:14] Model Load: 420.5 ms | Prompt: 1150.4 t/s | Eval: 98.2 t/s                        |
+-----------------------------------------------------------------------------------------------+
| Status: Benchmark completed successfully.                                                     |
+-----------------------------------------------------------------------------------------------+
```

---

## 📋 Prerequisites

1. **Operating System:** Windows 10 or Windows 11 (x64).
2. **PowerShell:** PowerShell 5.1 (built-in Windows PowerShell) or PowerShell 7+ (`pwsh`).
3. **.NET Framework:** .NET Framework 4.7.2 or later (for WPF and WindowsBase).
4. **llama.cpp Executables:** One or more compiled `llama-cli.exe` binaries.
5. **GGUF Model:** At least one valid `.gguf` model file.

---

## 🚀 Usage Guide

### 1. Launching the Suite

Open PowerShell and execute the script:

```powershell
cd E:\scripts\powershell\misc\llama-bench
.\llama.bench.ps1
```

### 2. Configure Benchmark Run

1. **Model Selection:** Click **Browse...** to select your `.gguf` model file.
2. **Set Parameters:**
   - **Threads (`-t`)**: Adjust CPU threads (defaults to `8`).
   - **GPU Layers (`-ngl`)**: Set offload layers (defaults to `99` for full GPU offload).
   - **Context Size (`-c`)**: Context window size in tokens (defaults to `4096`).
   - **Chat Template**: Optional path to a `.jinja` template or template keyword.
3. **Add Executables:** Click **Add Build...** and select one or more `llama-cli.exe` files.
4. **Select Scenarios:** Toggle any combination of the 3 built-in scenarios.

### 3. Run & View Results

1. Click **Start Benchmark**.
2. Observe live progress and timings in the log window.
3. Once completed, click **Open HTML Report** to view the generated interactive Chart.js comparison in your default browser.

---

## 📂 Output Artifacts

Reports are saved alongside the script:
- `llama_benchmark_report_YYYYMMDD_HHMMSS.html`: Standalone HTML report with responsive dark theme and Chart.js visualizations.
- `assets/chart.umd.min.js`: Local Chart.js library bundle downloaded automatically for offline reliability.

---

## ⚠️ Disclaimer

Benchmark throughput is sensitive to background system load, thermal throttling, and memory contention. For accurate comparative measurements, close heavy background processes before running tests. Use at your own risk.

---

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Author:** Adromir  
**Website:** [https://github.com/adromir](https://github.com/adromir)
