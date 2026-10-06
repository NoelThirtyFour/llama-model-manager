# Changelog

## 0.4.0

- Add `llama-modelctl tune MODEL` with an adaptive time budget based on GGUF size.
- Tune measurable performance parameters only: batch/ubatch, KV cache, Flash Attention and memory fitting.
- Store tuning results per backend/device and goal (`balanced`, `throughput`, `capacity`).
- Re-apply a matching measured tuning profile automatically at boot when available.
- Keep the HX370/ROCm policy of F16/F16 KV regardless of CUDA tuning results.
- Add `llama-modelctl sampling MODEL PRESET` with `hf`, `coding-agent`, `general-agent`, `creative`, and `precise` presets.
- `sampling ... hf` first tries `generation_config.json`, then explicit values in the Hugging Face README/model card.
- Remember Hugging Face repo/revision/file metadata for models added from HF.
- Keep sampling and performance tuning separate: speed benchmarks never guess which sampling values produce better answers.
- Fix installer home detection when accidentally invoked through `sudo ./install.sh`.
- Make `make test` invoke the smoke test through Bash so a Windows checkout cannot break it by dropping the executable bit.

## 0.3.0

- Add backend policy selection: `auto`, `cuda`, `hip`/`rocm`, `vulkan`, `cpu`.
- Add exact device pinning (`--device CUDA1`, `Vulkan1`, ...).
- Add performance profiles: `balanced`, `throughput`, `capacity`.
- Add selective llama.cpp rebuild backends via `update --backends`.
- Add OpenCode JSON export.
- Preserve KV preferences across AMD/HX370 F16 runtime overrides.
