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

* 🎯 **4 Flexible Benchmark Modes:**
  * **Compare Builds:** Benchmark multiple `llama-cli.exe` builds (CUDA vs. ROCm vs. Vulkan vs. CPU AVX2) using 1 model and identical parameters.
  * **Compare Models:** Benchmark 1 executable across multiple `.gguf` models (e.g. comparing quants Q4_K_M vs. Q5_K_M vs. Q8_0, or different model architectures).
  * **Parameter Sweep:** Benchmark 1 executable and 1 model across parameter scaling configurations (threads, GPU offload layers, context sizes, KV-cache quantizations, Flash Attention, batching).
  * **Custom Matrix Benchmark (Freie Konfigurationen):** Fully asymmetric comparison allowing each candidate to use a completely different build, different model, and unique parameter flags (e.g. testing Build A with DFlash 2 against Build B without DFlash 2).
* 💾 **Precise VRAM Utilization & Buffer Footprint Tracking:**
  * Extracts exact memory allocation metrics directly from the inference engine: Tensor Model Buffer, KV Cache allocation, Compute buffer, and Total VRAM footprint (MiB).
  * Features a dedicated VRAM Memory Allocation comparison bar chart in the HTML report.
  * Displays a detailed VRAM memory column in the results table broken down by component.
* 🔬 **Granular Single-Run Metrics & Variance Analysis:**
  * Tracks every individual execution run (Runs 1..N) to compute arithmetic averages, minimums, maximums, and sample standard deviations ($\pm \sigma$).
  * Interactive accordion disclosure (`▶ Show N Runs`) in the HTML report revealing complete per-run prompt speeds, generation speeds, load times, and VRAM buffers.
  * Global 1-click **Expand All Runs / Collapse All Runs** button for instant multi-run audits.
* 🎛️ **Dedicated Visual Profile Manager GUI Modal:**
  * Interactive WPF Dialog (`ProfileDialog.xaml`) to manage, inspect, edit, and duplicate profiles.
  * Full graphical controls for all inference parameters: thread count, GPU layers, context length, batch/ubatch, KV-cache quantization (`f16`, `q8_0`, `q4_0`, `turbo2`, `turbo3`, `turbo4`), memory flags (`--mlock`, `--mmap`), and speculative decoders (`--dflash`, `--gdn-replay`).
  * 1-click **Manage Profiles...** and **Save Current as Profile...** buttons in the main window.
* ⚡ **Universal Architecture-Agnostic Tuning Presets:**
  * **Full GPU Offload (Max VRAM):** All layers to GPU (`-ngl 99`), Flash Attention (`-fa on`), `-b 2048 -ub 512`, `--mlock`, 8k context.
  * **Hybrid Offload (RAM + VRAM):** Partial GPU offload (`-ngl 24`), Q8_0 KV-cache, Flash Attention, 8 threads, `--mlock`.
  * **Ultra-Context (TurboQuant turbo2):** 2-bit TurboQuant KV-cache (`-ctk/-ctv turbo2`) for extreme 16k+ contexts in limited VRAM.
  * **Balanced Quality (TurboQuant turbo4):** 4-bit TurboQuant KV-cache (`-ctk/-ctv turbo4`) balancing memory reduction with generation accuracy.
  * **Speculative Decoding (DFlash + MTP):** DFlash 2 speculative decoding acceleration (`--dflash`) & MTP rollback (`--gdn-replay`).
  * **High-Performance CPU:** Pure CPU execution (`-ngl 0`) with customizable worker thread count and optional core pinning.
* 🧩 **Universal CPU Thread Affinity Bitmask:**
  * Standard hexadecimal bitmask (e.g. `0xFF` for Cores 0–7, `0x0F` for Cores 0–3, `0xFFFF` for 16 cores) to pin worker threads to specific performance cores, CCDs, or NUMA nodes across any CPU vendor (Intel or AMD).
* 🎛️ **Advanced Performance Tuning Expander:**
  * **Batching:** Logical batch size (`-b`, default 2048) and physical micro-batch (`-ub`, default 512) to avoid VRAM allocation spikes.
  * **KV-Cache Quantization:** Selectable data types for K and V (`f16`, `q8_0`, `q4_0`, `turbo2`, `turbo3`, `turbo4`).
  * **Flash Attention:** Mandatory high-efficiency attention (`-fa on`) drastically cutting VRAM consumption and boosting prefill.
  * **Memory Management:** Direct weight memory mapping (`--mmap`) and physical RAM locking (`--mlock`) to avoid Windows pagefile swapping.
  * **CPU Thread Affinity:** Restricts worker thread affinity via custom hex bitmask without relying on vendor-specific tooling.
  * **Speculative Decoding:** Toggle DFlash 2 (`--dflash`) and Multi-Token Prediction replay (`--gdn-replay`).
* ⚡ **Quick Sweep Presets:** 1-click generators for standard scaling experiments:
  * **Thread Scaling:** 2, 4, 8, 12, 16 threads
  * **GPU Offload Scaling:** 0 (pure CPU), 16, 33, 99 (full offload) layers
  * **Context Scaling:** 1024, 2048, 4096, 8192 tokens
  * **KV-Cache Scaling:** f16 vs. q8_0 vs. q4_0 vs. turbo4 vs. turbo2
  * **Flash Attention Scaling:** Flash-Attn Off vs. On
  * **Batch Size Scaling:** b512/ub256 vs. b2048/ub512 vs. b4096/ub1024
* 🎮 **Universal GPU & Accelerator Selection:**
  * Automatically detects GPU accelerators across vendors (AMD ROCm, NVIDIA CUDA, Intel SYCL, OpenCL/Vulkan) via `llama-cli.exe --list-devices` with fallback to Windows WMI.
  * Allows selecting the exact graphics card, retaining system auto-selection, or forcing pure CPU execution (`-ngl 0`).
  * Seamlessly applies isolated device binding (`HIP_VISIBLE_DEVICES`, `CUDA_VISIBLE_DEVICES`, or `-dev <Id>`) without crashing dual-GPU/APU systems.
* 🔁 **Multi-Run Repetitions (Statistically Sound Averaging):**
  * Configurable benchmark runs per scenario (default 10 runs; selectable 1, 3, 5, 10, or custom).
  * Automatically calculates robust arithmetic averages for prompt evaluation speed, token generation throughput, and model load times, eliminating single-run variance.
* 📜 **Bundled Benchmark Jinja Template:** Includes a clean, zero-overhead `templates/benchmark.jinja` template to standardize chat formatting and eliminate conversational bloat during benchmarking.
* 🔥 **Model Warmup Phase:** Automatically primes GPU VRAM allocations, shader pipelines, and system page caches with a lightweight warm-up pass before executing measured runs. Can be toggled on/off with a single click.
* 📊 **Interactive Offline HTML Reports:** Generates standalone, responsive HTML reports featuring bundled [Chart.js](https://www.chartjs.org/) bar charts (Generation Speed, Prompt Speed, VRAM Allocation, Load Time) and granular timing breakdown tables. Auto-adapts charts and column headers based on active benchmark mode.
* 🧪 **Standardized Real-World Workload Scenarios:**
  * **Scenario 1: Quick Q&A (96 Tokens Out):** First-token responsiveness and low-latency throughput under short prompt conditions.
  * **Scenario 2: Code & Architecture (256 Tokens Out):** Multi-step code synthesis and balanced inference throughput.
  * **Scenario 3: Heavy Context Prefill (1200+ Tokens In, 64 Tokens Out):** Massive GEMM matrix multiplication stress test; forces continuous GPU compute utilization to reveal real compiler optimization differences.
  * **Scenario 4: Sustained Generation (512 Tokens Out):** Extended autoregressive decoding stress test; benchmarks continuous VRAM memory bandwidth throughput and thermal stability.
* 📈 **Comprehensive Metric Extraction:** Parses precise engine metrics:
  * **Cold Model Load Time** (ms average: SSD read, VRAM allocation, and kernel pipeline initialization)
  * **Prompt Processing Speed** (tokens/second average)
  * **Token Generation Speed** (tokens/second average)
  * **VRAM Memory Footprint** (MiB: Model, KV-Cache, Compute Buffer, Total)
* 🎨 **Modern Dark WPF GUI:** Built with an eye-friendly Catppuccin-inspired dark theme, real-time progress bar, responsive background dispatching, and live execution logging.
* 🌐 **Live Multilingual UI:** Seamless instant switching between **English** and **German** interface text.

---

## 📸 Interface Preview

```text
+-----------------------------------------------------------------------------------------------+
| 🦙 llama.cpp Build Benchmark Suite                                          Language: [ EN v ] |
+-----------------------------------------------------------------------------------------------+
| [ Model & Parameters ]                                                                        |
|  GGUF Model Path: [ C:\models\Llama-3.1-8B-Instruct.Q4_K_M.gguf          ] [ Browse... ]     |
|  Threads (-t): [ 8 ]      GPU Layers (-ngl): [ 99 ]      Context Size (-c): [ 4096 ]          |
|  GPU Device: [ ROCm1: AMD Radeon RX 9060 XT               v ] [ Refresh ] Runs/Test: [ 10  v ]|
|  Chat Template: [                                                         ] [ Browse... ]     |
+-----------------------------------------------------------------------------------------------+
| [ llama.cpp Executables ]                     | [ Test Suite Scenarios ]                       |
| +-------------------------------------------+ | [x] Warmup Model before benchmark (1 run)     |
| | C:\builds\llama-rocm-experimental\llama...| | ---------------------------------------------- |
| | C:\builds\llama-rocm-vanilla\llama-cli... | | [x] Scenario 1: Quick Q&A (96 t out)           |
| |                                           | | [x] Scenario 2: Code & Logic (256 t out)       |
| +-------------------------------------------+ | [x] Scenario 3: Heavy Prefill (1200+ t in)     |
| [ Add Build... ] [ Remove Selected ] [ Clear ]| [x] Scenario 4: Sustained Generation (512 t)   |
|                                               |                                               |
|                                               | Scenarios evaluate:                           |
|                                               | • Prompt evaluation throughput (tokens/sec)   |
|                                               | • Generation throughput (tokens/sec)          |
|                                               | • Cold model load time (milliseconds)         |
+-----------------------------------------------------------------------------------------------+
| [ Start Benchmark ]   [ Open HTML Report ]   [========================>              ] 66%    |
+-----------------------------------------------------------------------------------------------+
| [ Execution Log ]                                                                             |
| [14:20:10] Running benchmark on: llama-rocm / Scenario 1...                                   |
| [14:20:12]   [Run 1/10] Prompt = 178.4 t/s | Eval = 57.6 t/s                                  |
| [14:20:14]   [Run 2/10] Prompt = 181.8 t/s | Eval = 57.3 t/s                                  |
| [14:20:25] Average (10 runs): Prompt = 180.2 t/s | Eval = 57.5 t/s | Load = 412 ms            |
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

1. **Select Benchmark Mode:**
   - **Compare Builds:** Select 1 GGUF model and base parameters, then click **Add Build...** to add multiple `llama-cli.exe` binaries.
   - **Compare Models:** Select 1 `llama-cli.exe` binary and base parameters, then click **Add Models...** to add multiple `.gguf` files (supports multi-selection for comparing quants like Q4_K_M vs Q5_K_M vs Q8_0).
   - **Parameter Sweep:** Select 1 `llama-cli.exe` binary and 1 GGUF model. Add custom parameter configurations or select a **Quick Sweep Preset** (Threads `2, 4, 8, 12, 16`, GPU Offload `0, 16, 33, 99`, or Context `1024, 2048, 4096, 8192`) and click **+ Add Sweep**.
2. **Select Hardware & Execution Settings:**
   - **GPU Device:** Choose your target graphics card from the detected list (e.g. AMD ROCm, NVIDIA CUDA, Intel Arc), choose `Auto / System Default`, or select `CPU Only`. Click **Refresh** to re-detect devices at any time.
   - **Runs per Test:** Select the repetition count (1, 3, 5, 10, or enter a custom integer). 10 runs is recommended for statistically stable averages.
   - **Model Warmup:** Check **Warmup Model before benchmark** to prime GPU memory allocations and shader pipelines before measuring.
3. **Chat Template (Optional):** Click **Use Benchmark Jinja** to load the bundled zero-overhead template or **Browse...** to pick a custom `.jinja` file.
4. **Select Scenarios:** Toggle any combination of the 3 built-in scenarios (Short Query, Code & Logic, Long Context Prefill).

### 3. Run & View Results

1. Click **Start Benchmark**.
2. Observe live progress and timings in the log window.
3. Once completed, click **Open HTML Report** to view the generated interactive Chart.js comparison in your default browser.

---

## 📁 Architecture & File Structure

The project strictly separates functional business logic, graphical layout/design, and multilingual resources:

```text
powershell/misc/llama-bench/
├── llama.bench.ps1               # Pure functional controller & benchmark execution engine
├── MainWindow.xaml               # Declarative WPF main XAML layout & Catppuccin theme
├── ProfileDialog.xaml            # Dedicated Profile Manager modal WPF XAML layout
├── profiles.json                 # Universal performance presets
├── lang/
│   ├── en.json                   # English UI and status translations
│   └── de.json                   # German UI and status translations
├── templates/
│   ├── benchmark.jinja           # Minimal zero-overhead benchmark chat template
│   └── report_template.html      # Responsive HTML/CSS/Chart.js report layout template
├── assets/                       # Bundled offline libraries (chart.umd.min.js)
├── README.md                     # Documentation
└── MEMORY.md                     # Project context & decision log (git-ignored)
```

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
