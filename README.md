# llama-model-manager

Small Linux helper for a `llama.cpp` router using `llama-server --models-preset`.
It is designed for machines that can boot with different GPUs, for example an
AMD Ryzen AI HX370 iGPU/UMA system with an optional NVIDIA eGPU.

## What it does

- Keeps `~/llama-models.ini` as the normal llama.cpp preset file.
- At service startup, detects available devices with `llama-server --list-devices`.
- Prefers CUDA, then ROCm, then Vulkan.
- With multiple CUDA devices, selects the CUDA device with the most **free VRAM**.
- Sets `n-gpu-layers = auto` and `fit = on`; llama.cpp decides the actual offload.
- Uses a VRAM margin (`fit-target`) based on the selected device.
- Supports per-model **fixed** or **auto-fit** context sizes.
- Adds/removes GGUF models from local files or Hugging Face.
- Downloads sharded GGUFs and a suitable `mmproj` when available.
- Edits advanced preset parameters (`top-k`, `top-p`, KV cache types, etc.).
- Updates and rebuilds `~/llama.cpp/build-all` with CUDA + HIP/ROCm + Vulkan.

Current llama.cpp supports `n-gpu-layers = auto`, `fit = on`, `fit-target` and
`fit-ctx`; this project delegates memory fitting to llama.cpp instead of
hard-coding layer counts for a 3060, 3090, etc.

## Assumptions

Default paths:

```text
~/llama.cpp
~/llama.cpp/build-all/bin/llama-server
~/llama-models.ini
/models-local
systemd service: llama-main
```

All can be overridden with environment variables:
`LLAMA_CPP_DIR`, `LLAMA_SERVER`, `LLAMA_MODELS_INI`, `LLAMA_MODELS_DIR`,
`LLAMA_SERVICE`, `LLAMA_MODELCTL_STATE`.

## Install

```bash
git clone <YOUR-REPO-URL>
cd llama-model-manager
./install.sh
```

The installer copies the tools to `/usr/local/bin`, ensures `/models-local` is
writable by the current user, and adds this systemd drop-in to `llama-main`:

```ini
[Service]
ExecStartPre=/usr/local/bin/llama-hw-select
```

The selector therefore runs automatically at every service start / boot.

## Device selection

Example device list:

```text
CUDA0: NVIDIA GeForce RTX 3060 (...)
ROCm0: AMD Radeon Graphics (...)
Vulkan0: NVIDIA GeForce RTX 3060 (...)
Vulkan1: AMD Radeon Graphics (...)
```

Selection order:

1. CUDA device with the most free VRAM
2. ROCm device with the most free memory
3. NVIDIA Vulkan
4. Other Vulkan

The selector writes only dynamic hardware settings into the INI and removes
per-model `device`, `n-gpu-layers`, `fit-target` and `main-gpu` overrides so
models inherit the boot-selected hardware.

## Commands

### List / inspect

```bash
llama-modelctl list
llama-modelctl show qwen38-iq3s
llama-modelctl devices
```

### Add from Hugging Face

Direct model URL:

```bash
llama-modelctl add qwen38-iq3s \
  https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/blob/main/Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf
```

Repo + filename/pattern:

```bash
llama-modelctl add qwen38-iq3s \
  ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF \
  --file 'Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf'
```

New models default to **automatic context fitting** with a 4096-token minimum.
Override that while adding:

```bash
llama-modelctl add my-model USER/REPO --file '*Q4_K_M*.gguf' \
  --ctx auto --fit-ctx 16384
```

Or force a fixed context:

```bash
llama-modelctl add my-model /path/model.gguf --ctx 65536
```

### Context control

Auto-fit context:

```bash
llama-modelctl ctx qwen38-iq3s auto --fit-ctx 4096
```

Fixed context:

```bash
llama-modelctl ctx qwen38-iq3s 65536
```

Show current modelctl context mode:

```bash
llama-modelctl ctx qwen38-iq3s
```

For auto mode, `ctx-size` is removed and `fit-ctx` is set. This lets llama.cpp
fit both context and GPU layers to the current memory. A fixed `ctx-size` is
preserved exactly.

### Advanced parameters

```bash
llama-modelctl set qwen38-iq3s top-k 20
llama-modelctl set qwen38-iq3s top-p 0.95
llama-modelctl set qwen38-iq3s temp 1.0
llama-modelctl set qwen38-iq3s cache-type-k q8_0
llama-modelctl set qwen38-iq3s cache-type-v q8_0
```

Return to F16 KV:

```bash
llama-modelctl set qwen38-iq3s cache-type-k f16
llama-modelctl set qwen38-iq3s cache-type-v f16
```

Hardware-managed keys such as `device`, `n-gpu-layers`, `fit-target`,
`main-gpu`, `split-mode` and `fit` are intentionally protected from per-model
`set` operations.

### Remove

Preset only:

```bash
llama-modelctl remove qwen38-iq3s
```

Preset and its `/models-local/<name>/` directory:

```bash
llama-modelctl remove qwen38-iq3s --files
```

### Update llama.cpp

```bash
llama-modelctl update
```

This performs:

```text
git pull --ff-only
cmake configure build-all
  GGML_BACKEND_DL=ON
  GGML_CUDA=ON
  GGML_HIP=ON
  GGML_VULKAN=ON
  GGML_NATIVE=OFF
cmake --build
llama-server --list-devices
restart llama-main
```

ROCm/HIP 6.1 or newer is required by current llama.cpp HIP sources.

## 3060 vs 3090 vs HX370

There is deliberately no hard-coded `3090 => n-gpu-layers=99` table.
`n-gpu-layers = auto` plus `fit = on` lets llama.cpp use the amount of VRAM
actually available for each individual model.

For example, a 12 GB RTX 3060 may only fit part of a model, while a 24 GB RTX
3090 can fit many more layers or the entire model. On an HX370 with large UMA,
the same presets can run through ROCm with a larger reserved system-memory
margin.

## State file

Context mode metadata is stored separately in:

```text
~/.config/llama-modelctl/state.json
```

This avoids adding unsupported custom keys to `llama-models.ini`.
Existing models with no state entry keep their existing context behavior until
you explicitly run `llama-modelctl ctx ...`.

## Safety / backups

Every command that edits `~/llama-models.ini` creates a timestamped backup.
`remove --files` refuses to recursively remove anything outside `/models-local`.

## Uninstall

```bash
./uninstall.sh
```

This removes the tools and systemd drop-in. It does **not** delete models,
`llama.cpp`, your INI, or state file.
