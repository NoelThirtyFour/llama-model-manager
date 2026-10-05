# Changelog

## 0.1.0

- Automatic CUDA -> ROCm -> Vulkan device selection at service start.
- Multi-CUDA selection by free VRAM.
- llama.cpp auto offload with `n-gpu-layers=auto` and `fit=on`.
- Fixed or auto-fit per-model context management.
- Hugging Face/local GGUF add, remove, show, list and advanced set/unset.
- Automatic mmproj/shard handling.
- `llama-modelctl update` for CUDA + HIP/ROCm + Vulkan `build-all` rebuilds.
