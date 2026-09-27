# vast-llm

`vast-llm` is a native NVIDIA/CUDA llama.cpp manager for Vast.ai and ordinary Linux GPU servers.

It detects the machine, recommends GGUF models that fit the available VRAM, can build/fix a CUDA-enabled `llama-server`, downloads models from Hugging Face, creates reusable profiles, starts independent GPU replicas, and includes tuning + benchmark tooling.

**Docker is not required.**

## Fast path on a fresh Vast.ai NVIDIA server

Start from a normal Ubuntu/CUDA instance where `nvidia-smi` can see the GPU(s):

```bash
git clone https://github.com/AlexRzk/vast-llm.git
cd vast-llm
bash install.sh
```

Then:

```bash
vast-llm hardware
vast-llm recommend
vast-llm bootstrap
```

`bootstrap` does four things:

1. detects NVIDIA GPU(s), VRAM, compute capability, driver/CUDA, system RAM and model-disk space;
2. checks the llama.cpp CUDA backend and runs the CUDA doctor when a native runtime needs to be built/repaired;
3. shows only catalog models that fit the smallest selected GPU replica;
4. lets you create, download and start the recommended profile.

You can also just run:

```bash
vast-llm
```

and use the interactive menu.

## Hardware discovery

```bash
vast-llm hardware
```

Example shape:

```text
Hardware discovery
  Host:          vast-instance
  OS:            Ubuntu ...
  CPU threads:   16
  System RAM:    64.0 GB
  Model disk:    180 GB free (/data/models)
  CUDA (driver): 12.x
  GPUs:          2

  ID   GPU                               VRAM MiB   FREE MiB       CC       DRIVER
  0    NVIDIA GeForce RTX 3090              24576      24200      8.6       ...
  1    NVIDIA GeForce RTX 3090              24576      24200      8.6       ...
```

## Automatic model recommendations

```bash
vast-llm recommend
```

The advisor currently has recommendation tiers for models such as:

- Qwen3.8 27B Q4/Q5 — strong general/reasoning/agent use;
- Qwen3-Coder 30B-A3B Q4 — coding / OpenCode implementation;
- Gemma 4 31B — high-quality dense general model;
- Gemma 4 26B-A4B — fast MoE general/agent model;
- Gemma 4 12B, Qwen3.5 9B and Gemma 4 E4B for smaller GPUs.

The fit calculation deliberately uses **VRAM per GPU**, not the sum of every card, because the current `GPU_IDS` mode launches one full independent model replica on each selected GPU. It does not tensor-parallelize one request across multiple GPUs.

`FIT` means the model fits the GPU and enough VRAM is currently free. `BUSY` means total VRAM is sufficient but another process is consuming too much of it right now.

The quality/speed tiers shown by the advisor are coarse selection hints, not benchmark results. Use the Benchmark Center for measured comparisons on the actual host.

## Auto-create a recommended profile

```bash
vast-llm auto-setup
```

The advisor:

- lets you choose a recommendation;
- resolves a matching GGUF filename from the current Hugging Face repository metadata;
- selects a conservative context size from model size + VRAM headroom;
- creates a normal `vast-llm` profile;
- optionally downloads and starts it.

The generated profiles remain editable with the normal wizard and quick settings.

## Native CUDA runtime / llama.cpp

Check the runtime:

```bash
vast-llm doctor --check
```

Automatically repair/build it:

```bash
vast-llm doctor --fix
```

The doctor can compile current llama.cpp with CUDA directly on the server and stores the repaired runtime under the `vast-llm` state directory. It also handles cases where an incompatible CUDA compatibility/stub library masks the real host NVIDIA `libcuda`.

No Docker daemon, Docker image, `/app/llama-server`, or container-specific llama.cpp binary is required.

If a compatible `llama-server` already exists in `$PATH`, the manager can use it instead.

## Storage layout

The installer chooses paths automatically.

If writable persistent `/data` storage exists (common on Vast.ai):

```text
/data/vast-llm        state, profiles, logs, PIDs, benchmarks, repaired runtime
/data/models          GGUF models
/data/huggingface     Hugging Face/Xet cache
```

Otherwise it falls back to user-owned storage:

```text
~/.local/share/vast-llm
~/.local/share/vast-llm/models
~/.cache/huggingface
```

You can override them before installation:

```bash
export VAST_LLM_STATE_DIR=/mnt/fast/vast-llm
export VAST_LLM_MODEL_DIR=/mnt/fast/models
bash install.sh
```

The installer writes the selected paths into the installed `vast-llm` environment so every subcommand uses the same storage automatically.

## Root and non-root installation

When run as root, the default install locations are:

```text
/usr/local/bin/vast-llm
/usr/local/lib/vast-llm/
```

For a non-root user they become:

```text
~/.local/bin/vast-llm
~/.local/lib/vast-llm/
```

If `~/.local/bin` is not already in `PATH`, the installer tells you to add it.

## Profiles

Manual profile creation still works:

```bash
vast-llm wizard my-model
```

Useful commands:

```bash
vast-llm profiles
vast-llm use my-model
vast-llm show my-model
vast-llm download my-model
vast-llm start my-model
vast-llm stop my-model
vast-llm restart my-model
vast-llm status my-model
vast-llm logs
```

A profile controls:

- Hugging Face repository + GGUF file;
- API alias and port;
- GPU IDs;
- context and parallel slots;
- GPU layers;
- Flash Attention;
- KV-cache quantization;
- cache reuse;
- MTP/speculative decoding;
- reasoning mode/budget;
- Jinja and mmproj behavior;
- arbitrary extra llama.cpp arguments.

## Multi-GPU behavior

Given:

```text
GPU_IDS=0,1
PORT_BASE=8000
ALIAS_BASE=qwen
```

`vast-llm` starts:

```text
GPU 0 -> 127.0.0.1:8000 -> qwen-0
GPU 1 -> 127.0.0.1:8001 -> qwen-1
```

Those are independent replicas. This is useful for setups such as:

```text
GPU 0 -> implementation agent
GPU 1 -> reviewer/subagent
```

VRAM is not pooled between them.

## Quick tuning

Open the tuning UI:

```bash
vast-llm settings my-model
```

or change values directly:

```bash
vast-llm set context 65536 my-model
vast-llm set kv-k q4_0 my-model
vast-llm set kv-v q4_0 my-model
vast-llm set mtp on my-model
vast-llm set mtp-draft 4 my-model
vast-llm restart my-model
```

## Benchmark Center

```bash
vast-llm benchmarks
```

CLI examples:

```bash
vast-llm bench-suite my-model quick
vast-llm bench-suite my-model full
vast-llm bench-speed my-model 0 3
vast-llm bench-quality my-model
vast-llm bench-needle my-model 20000
vast-llm bench-history
```

See [`BENCHMARKS.md`](BENCHMARKS.md) for the methodology.

## OpenAI-compatible API / OpenCode

Servers bind to `127.0.0.1` by default. Use SSH forwarding rather than exposing the API directly.

Example:

```powershell
ssh -N `
  -i "$env:USERPROFILE\.ssh\id_ed25519" `
  -L 8000:127.0.0.1:8000 `
  -p YOUR_VAST_SSH_PORT `
  root@YOUR_VAST_IP
```

Then point an OpenAI-compatible client at:

```text
http://127.0.0.1:8000/v1
```

Get the generated API key with:

```bash
vast-llm key
```

## Hugging Face authentication

Public repositories need no token. For gated/private repositories:

```bash
export HF_TOKEN="hf_..."
```

Do not commit tokens to the repository.

## Important notes

- The recommendation catalog intentionally leaves VRAM headroom for context/KV/runtime allocations rather than comparing only raw GGUF file size.
- MTP support differs by architecture and GGUF. Auto profiles only enable it where the catalog marks the configuration as safe; the manual wizard remains available for custom draft models/arguments.
- The advisor is a curated starting point. Actual speed depends heavily on GPU memory bandwidth, model architecture (dense vs MoE), quantization, context length and llama.cpp kernels.
- `vast-llm doctor --fix` may require build tools/CUDA toolkit packages if no usable native llama.cpp exists.
- Keep APIs bound to localhost unless you intentionally add proper network/authentication controls.
