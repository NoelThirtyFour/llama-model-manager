#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.config/llama-modelctl" "$T/bin" "$T/models" "$T/repo/build-all/bin"
cat > "$T/home/llama-models.ini" <<'INI'
version = 1
[*]
models-max = 1
device = ROCm0
n-gpu-layers = auto
fit = on
fit-target = 8192

[qwen]
model = __QWEN_MODEL__
alias = qwen
ctx-size = 65536
batch-size = 512
ubatch-size = 256
cache-type-k = q8_0
cache-type-v = q4_0
n-predict = 8192

[embed]
model = /tmp/embed.gguf
embeddings = true
ctx-size = 8192
INI
sed -i "s|__QWEN_MODEL__|$T/qwen.gguf|" "$T/home/llama-models.ini"
truncate -s 1048576 "$T/qwen.gguf"
cat > "$T/bin/llama-server" <<'SERVER'
#!/usr/bin/env bash
cat <<TXT
Available devices:
  CUDA0: NVIDIA GeForce RTX 3060 (11911 MiB, 11754 MiB free)
  ROCm0: AMD Radeon Graphics (86016 MiB, 70836 MiB free)
  Vulkan0: NVIDIA GeForce RTX 3060 (12534 MiB, 11987 MiB free)
  Vulkan1: AMD Radeon Graphics (RADV GFX1150) (88064 MiB, 72693 MiB free)
TXT
SERVER
chmod +x "$T/bin/llama-server"

cp "$T/bin/llama-server" "$T/repo/build-all/bin/llama-server"
cat > "$T/repo/build-all/bin/llama-bench" <<'BENCH'
#!/usr/bin/env python3
import json,sys
args=sys.argv[1:]
def val(flag, default=None):
    try: return args[args.index(flag)+1]
    except Exception: return default
b=int(val('-b','128')); ub=int(val('-ub','128')); ctk=val('-ctk','f16'); fa=val('-fa','on')
# Deterministic synthetic result: q8_0 + 128/128 + FA on wins.
bonus=(30 if ctk=='q8_0' else 0)+(20 if b==128 and ub==128 else 0)+(10 if fa=='on' else 0)
print(json.dumps([
 {'n_prompt':1024,'n_gen':0,'avg_ts':200.0+bonus,'samples_ts':[200.0+bonus]},
 {'n_prompt':0,'n_gen':64,'avg_ts':10.0+bonus/10,'samples_ts':[10.0+bonus/10]}
]))
BENCH
chmod +x "$T/repo/build-all/bin/llama-server" "$T/repo/build-all/bin/llama-bench"
export LLAMA_HOME="$T/home"
export LLAMA_MODELS_INI="$T/home/llama-models.ini"
export LLAMA_SERVER="$T/bin/llama-server"
export LLAMA_MODELCTL_STATE="$T/home/.config/llama-modelctl/state.json"
export LLAMA_CPP_DIR="$T/repo"
export LLAMA_MODELS_DIR="$T/models"

python3 "$ROOT/bin/llama-hw-select" >/dev/null
grep -q '^device = CUDA0$' "$LLAMA_MODELS_INI"

python3 - <<'PY'
import json,os
p=os.environ['LLAMA_MODELCTL_STATE']; s=json.load(open(p)); s.setdefault('hardware',{}).update({'backend':'rocm'}); json.dump(s,open(p,'w'))
PY
python3 "$ROOT/bin/llama-hw-select" >/dev/null
awk '/\[qwen\]/{f=1;next} /^\[/{f=0} f' "$LLAMA_MODELS_INI" | grep -q '^cache-type-k = f16$'

python3 - <<'PY'
import json,os
p=os.environ['LLAMA_MODELCTL_STATE']; s=json.load(open(p)); s['hardware']={'backend':'cuda','profile':'throughput'}; json.dump(s,open(p,'w'))
PY
python3 "$ROOT/bin/llama-hw-select" >/dev/null
Q="$(awk '/\[qwen\]/{f=1;next} /^\[/{f=0} f' "$LLAMA_MODELS_INI")"
grep -q '^cache-type-k = q8_0$' <<<"$Q"
grep -q '^cache-type-v = q4_0$' <<<"$Q"
grep -q '^batch-size = 128$' <<<"$Q"
grep -q '^ubatch-size = 128$' <<<"$Q"

python3 "$ROOT/bin/llama-modelctl" export-opencode --base-url http://192.168.1.50:8080/v1 > "$T/opencode.json"
python3 - "$T/opencode.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
p=j['providers']['llama-local']
assert p['settings']['baseURL']=='http://192.168.1.50:8080/v1'
assert 'qwen' in p['models']
assert 'embed' not in p['models']
assert p['models']['qwen']['modelID']=='qwen'
PY


python3 "$ROOT/bin/llama-modelctl" sampling qwen coding-agent --no-restart >/dev/null
Q="$(awk '/\[qwen\]/{f=1;next} /^\[/{f=0} f' "$LLAMA_MODELS_INI")"
grep -q '^temp = 0.3$' <<<"$Q"
grep -q '^top-k = 20$' <<<"$Q"

python3 "$ROOT/bin/llama-modelctl" tune qwen --minutes 0.2 --goal throughput --device CUDA0 --apply --no-restart >/dev/null
Q="$(awk '/\[qwen\]/{f=1;next} /^\[/{f=0} f' "$LLAMA_MODELS_INI")"
grep -q '^batch-size = 128$' <<<"$Q"
grep -q '^ubatch-size = 128$' <<<"$Q"
grep -q '^cache-type-k = q8_0$' <<<"$Q"
grep -q '^flash-attn = on$' <<<"$Q"

echo "smoke tests: OK"
