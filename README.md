# llama-model-manager

A small Linux toolkit for running `llama.cpp` with one model catalog across changing hardware.

It is designed for machines such as an AMD Ryzen AI HX370 / Radeon 890M host with an optional NVIDIA eGPU, but it also supports fixed CUDA, HIP/ROCm, Vulkan, and CPU modes.

## Highlights

- Keeps `~/llama-models.ini` as the source of model presets.
- Selects hardware automatically at service start, or lets you force a backend.
- Supports CUDA, HIP/ROCm, Vulkan, and CPU runtime modes.
- Chooses the CUDA device with the most free VRAM in automatic mode.
- Uses `n-gpu-layers = auto` and `fit = on` instead of hard-coded layer counts.
- Forces F16/F16 KV cache on AMD/HX370 and restores per-model Q8/Q4/F16 preferences on NVIDIA.
- Supports fixed or auto-fit context sizes per model.
- Downloads GGUF models from local files or Hugging Face, including shards and `mmproj`.
- Updates and rebuilds `llama.cpp` with selectable build backends.
- Exports an OpenCode JSON configuration for a remote OpenCode machine.

## Default layout

```text
~/llama.cpp
~/llama.cpp/build-all/bin/llama-server
~/llama-models.ini
/models-local
systemd service: llama-main
```

Paths can be overridden with `LLAMA_CPP_DIR`, `LLAMA_SERVER`, `LLAMA_MODELS_INI`, `LLAMA_MODELS_DIR`, `LLAMA_SERVICE`, and `LLAMA_MODELCTL_STATE`.

## Install

```bash
git clone https://github.com/NoelThirtyFour/llama-model-manager.git
cd llama-model-manager
./install.sh
```

The installer adds `/usr/local/bin/llama-modelctl` and `/usr/local/bin/llama-hw-select`, then installs an `ExecStartPre` hook for `llama-main` so hardware selection runs automatically at boot/service start.

## Runtime backend selection

Automatic mode is the default:

```bash
llama-modelctl backend auto
```

Force CUDA:

```bash
llama-modelctl backend cuda
```

Force HIP/ROCm:

```bash
llama-modelctl backend hip
# or
llama-modelctl backend rocm
```

Force Vulkan:

```bash
llama-modelctl backend vulkan
```

CPU fallback:

```bash
llama-modelctl backend cpu
```

On multi-GPU systems, pin an exact device:

```bash
llama-modelctl backend cuda --device CUDA1
llama-modelctl backend vulkan --device Vulkan1
```

Show the current policy:

```bash
llama-modelctl backend
```

### Automatic priority

When `backend auto` is active, the selector uses:

1. CUDA device with the most free VRAM
2. ROCm device with the most free memory
3. NVIDIA Vulkan
4. Other Vulkan

## Performance policy

Three runtime policies are available:

```bash
llama-modelctl profile balanced
llama-modelctl profile throughput
llama-modelctl profile capacity
```

`balanced` is the default.

`throughput` is an experimental NVIDIA-oriented policy that uses a tighter VRAM fit target and runtime `batch-size = 128` / `ubatch-size = 128`. Original per-model batch preferences are saved and restored when leaving this mode.

`capacity` keeps model-specific batch settings and uses a more aggressive memory-capacity fit target.

These policies are intentionally conservative helpers, not universal benchmark winners. Use `llama-bench` for model-specific tuning.

## HX370 / AMD KV policy

On ROCm or AMD Vulkan runtime:

```ini
cache-type-k = f16
cache-type-v = f16
```

is forced for runtime stability/performance.

If a model normally uses Q8 or Q4 KV cache, that preference is stored in `~/.config/llama-modelctl/state.json` and restored automatically when CUDA/NVIDIA becomes active again.

## Model commands

List models:

```bash
llama-modelctl list
```

Inspect a model:

```bash
llama-modelctl show qwen38-iq3s
```

Show detected devices:

```bash
llama-modelctl devices
```

### Add from Hugging Face

Direct URL:

```bash
llama-modelctl add qwen38-iq3s \
  "https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/blob/main/Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf"
```

Repository plus filename/pattern:

```bash
llama-modelctl add qwen38-iq3s \
  ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF \
  --file 'Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf'
```

Local file:

```bash
llama-modelctl add my-model /path/to/model.gguf
```

New models default to automatic context fitting with a 4096-token minimum.

## Context control

Automatic context fitting:

```bash
llama-modelctl ctx qwen38-iq3s auto --fit-ctx 16384
```

Fixed context:

```bash
llama-modelctl ctx qwen38-iq3s 65536
```

Show current context mode:

```bash
llama-modelctl ctx qwen38-iq3s
```

## Advanced model parameters

```bash
llama-modelctl set qwen38-iq3s top-k 20
llama-modelctl set qwen38-iq3s top-p 0.95
llama-modelctl set qwen38-iq3s temp 1.0
llama-modelctl set qwen38-iq3s cache-type-k q8_0
llama-modelctl set qwen38-iq3s cache-type-v q8_0
```

Remove a custom key:

```bash
llama-modelctl unset qwen38-iq3s reasoning-effort
```

Hardware-managed keys such as `device`, `n-gpu-layers`, `fit`, `fit-target`, `main-gpu`, and `split-mode` are protected from per-model edits.

## Remove models

Preset only:

```bash
llama-modelctl remove qwen38-iq3s
```

Preset and files under `/models-local`:

```bash
llama-modelctl remove qwen38-iq3s --files
```

## Update llama.cpp

Build all supported GPU backends:

```bash
llama-modelctl update
```

Select build backends explicitly:

```bash
llama-modelctl update --backends cuda
llama-modelctl update --backends hip
llama-modelctl update --backends vulkan
llama-modelctl update --backends cuda,hip,vulkan
llama-modelctl update --backends cpu
```

The command performs a `git pull --ff-only`, reconfigures `~/llama.cpp/build-all`, rebuilds, runs `llama-server --list-devices`, and restarts `llama-main` unless `--no-restart` is supplied.

## Export models for OpenCode

OpenCode may run on another Linux, Windows, or macOS machine. This project does not try to modify that remote machine. Instead it prints or writes a ready-to-place OpenCode configuration.

Print JSON to stdout:

```bash
llama-modelctl export-opencode \
  --base-url http://192.168.1.50:8080/v1
```

Write a file:

```bash
llama-modelctl export-opencode \
  --base-url http://192.168.1.50:8080/v1 \
  --output opencode.jsonc
```

Set a default model:

```bash
llama-modelctl export-opencode \
  --base-url http://192.168.1.50:8080/v1 \
  --default-model qwen38-27b-gsq-rco-iq3-s \
  --output opencode.jsonc
```

For models using automatic context fitting, the exporter uses the guaranteed `fit-ctx` minimum by default. Override the advertised OpenCode context if desired:

```bash
llama-modelctl export-opencode \
  --base-url http://192.168.1.50:8080/v1 \
  --auto-context 65536
```

Embedding/reranker presets are excluded. A model is exported with image input only when its configured `mmproj` exists.

OpenCode global config is normally placed at:

```text
~/.config/opencode/opencode.jsonc
```

The generated provider uses OpenCode's OpenAI-compatible package and points at the remote `llama-server` `/v1` endpoint.

## State file

Runtime metadata is stored separately from `llama-models.ini`:

```text
~/.config/llama-modelctl/state.json
```

It stores context mode, backend policy, performance policy, and preferences that need to survive runtime hardware rewrites.

## Backups

Commands that modify `~/llama-models.ini` create timestamped backups first.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes the tools and systemd integration. It does not delete models, `llama.cpp`, the INI file, or state data.

## Adaptive tuning

`llama-modelctl` can benchmark a model for a short, bounded period and keep the best measured settings for the current hardware.

```bash
llama-modelctl tune qwen38-iq3s
llama-modelctl tune qwen38-iq3s --goal throughput --apply
llama-modelctl tune deepseek-v4-flash-iq2 --minutes 10 --goal balanced --apply
```

If `--minutes` is omitted, the budget adapts to GGUF size:

| GGUF size | Default budget |
| --- | ---: |
| under 8 GiB | ~2 min |
| 8-20 GiB | ~4 min |
| 20-60 GiB | ~6 min |
| over 60 GiB | ~10 min |

The tuner measures only settings for which a speed benchmark is meaningful:

- batch size / micro-batch size
- KV cache format
- Flash Attention
- GPU memory fitting on the selected backend

Results are stored separately for each backend/device and goal. A result measured on `CUDA0` is therefore not reused as an HX370/ROCm result. When a matching result exists, the boot selector can reuse it automatically.

On AMD/HX370, the runtime KV policy remains **F16/F16** even if a CUDA tuning result prefers Q8 or Q4.

> `llama-bench` does not measure answer quality. The tuner deliberately does not optimize temperature, top-k, top-p, penalties, or other sampling parameters.

## Sampling presets

Sampling is managed separately from performance tuning:

```bash
llama-modelctl sampling qwen38-iq3s show
llama-modelctl sampling qwen38-iq3s hf
llama-modelctl sampling qwen38-iq3s coding-agent
llama-modelctl sampling qwen38-iq3s general-agent
llama-modelctl sampling qwen38-iq3s precise
llama-modelctl sampling qwen38-iq3s creative
```

`hf` is preferred when the model author publishes explicit defaults. For models installed from Hugging Face, the repo/revision is remembered automatically. The command first looks for a machine-readable `generation_config.json`, then for explicit sampling values in the model card.

For an older/local model whose Hugging Face source is not known:

```bash
llama-modelctl sampling my-model hf --repo USER/REPO
```

Built-in presets are fallbacks, not claims about the ideal settings for every model:

| Preset | Typical use |
| --- | --- |
| `coding-agent` | deterministic coding/tool agents |
| `general-agent` | general assistant/tool use |
| `precise` | low-variance factual/structured output |
| `creative` | prose, brainstorming, poems |

Changing a sampling preset edits only the sampling keys in that model section. It does not alter GPU/backend, context mode, KV policy, or tuning results.

## License

MIT
