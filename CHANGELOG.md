# Changelog

## 0.3.0

- Add runtime backend policy: `auto`, `cuda`, `hip`/`rocm`, `vulkan`, and `cpu`.
- Add exact runtime device pinning such as `--device CUDA1` or `Vulkan1`.
- Add `balanced`, `throughput`, and `capacity` runtime policies.
- Preserve/restore per-model batch preferences when using the experimental throughput policy.
- Add `llama-modelctl update --backends ...` to choose CUDA, HIP/ROCm, Vulkan, or CPU-only builds.
- Add `export-opencode` with `--base-url`, `--output`, `--default-model`, and `--auto-context`.
- Exclude embedding/reranker presets from OpenCode exports and only advertise vision when the `mmproj` exists.
- Keep HX370/AMD F16/F16 KV enforcement with automatic NVIDIA cache preference restoration.

## 0.2.0

- Preserve per-model KV cache preferences separately from runtime hardware overrides.
- Force `cache-type-k = f16` and `cache-type-v = f16` on AMD/HX370 runtime.
- Restore the user's preferred Q8/Q4/F16 KV cache automatically when CUDA/NVIDIA is selected again.
- Keep `n-gpu-layers = auto` and `fit = on` for dynamic 3060/3090/HX370 fitting.
- Validate fixed and auto-fit context behavior.

## 0.1.0

- Automatic CUDA -> ROCm -> Vulkan device selection at service start.
- Multi-CUDA selection by free VRAM.
- llama.cpp auto offload with `n-gpu-layers=auto` and `fit=on`.
- Fixed or auto-fit per-model context management.
- Hugging Face/local GGUF add, remove, show, list and advanced set/unset.
- Automatic mmproj/shard handling.
- `llama-modelctl update` for CUDA + HIP/ROCm + Vulkan `build-all` rebuilds.
