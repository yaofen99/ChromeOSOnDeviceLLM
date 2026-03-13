# Build & Test Log

Real build and test session on Ubuntu host with ChromiumOS source at `/data/chromiumos`.

---

## 1. Building the Package

```
$ sudo /data/chromiumos/chromite/bin/cros build-packages \
    --board=amd64-generic \
    chromeos-base/llm-service virtual/target-os virtual/target-os-dev

15:56:40.391: INFO: Selecting profile: /mnt/host/source/src/overlays/overlay-amd64-generic/profiles/base for /build/amd64-generic
15:56:43: NOTICE: Installed packages in amd64-generic: 1348

>>> 16:02:01.274 Installing (3 of 3) virtual/target-os-dev-2::amd64-generic to /build/amd64-generic/
>>> 16:02:03.265 Completed (3 of 3) virtual/target-os-dev-2::amd64-generic to /build/amd64-generic/

15:57:08: NOTICE: cros build-packages completed successfully.
```

llama.cpp compiled successfully. Key output from the llm-service build log:
```
>>> /build/amd64-generic/opt/llm-service/bin/
>>> /build/amd64-generic/opt/llm-service/bin/llama-server
>>> /build/amd64-generic/opt/llm-service/models/
>>> /build/amd64-generic/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf
>>> chromeos-base/llm-service-1.0.0 merged.
```

---

## 2. Building the Image

```
$ sudo /data/chromiumos/chromite/bin/cros build-image \
    --board=amd64-generic \
    --no-enable-rootfs-verification \
    test
```

Image built at:
```
/data/chromiumos/src/build/images/amd64-generic/R148-16613.0.0-d2026_03_12_162738-a1/chromiumos_test_image.bin
```

---

## 3. Verifying llm-service is in the Image

Mounted the stateful partition (partition 1) and confirmed:

```
$ find /mnt/cros_state -name "*llm*" -o -name "*llama*"

/mnt/cros_state/dev_image/etc/init/llm-service.conf
/mnt/cros_state/dev_image/opt/llm-service/bin/llama-server
/mnt/cros_state/dev_image/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf
/mnt/cros_state/dev_image/share/minijail/llm-service.minijail.conf
/mnt/cros_state/var_overlay/db/pkg/chromeos-base/llm-service-1.0.0

$ ls -lh /mnt/cros_state/dev_image/opt/llm-service/bin/llama-server
-rwxr-xr-x 1 root root 7.6M Mar 12 16:01 llama-server

$ ls -lh /mnt/cros_state/dev_image/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf
-rw-r--r-- 1 root root 1.1G Mar 12 16:01 qwen2.5-1.5b-instruct-q4_k_m.gguf
```

Both binary and model confirmed in the **stateful partition** (not ROOT-A).

---

## 4. Starting the VM

```
$ IMG=/data/chromiumos/src/build/images/amd64-generic/R148-16613.0.0-d2026_03_12_162738-a1/chromiumos_test_image.bin
$ sudo /data/chromiumos/chromite/bin/cros vm --start \
    --board=amd64-generic \
    --image-path "$IMG" \
    --copy-on-write \
    --ssh-port 9222 \
    --qemu-hostfwd tcp:127.0.0.1:8080-:8080 \
    --qemu-mem 8192 \
    --no-display \
    --wait-for-boot

Formatting '/tmp/cros_vm_9222/qcow2.img', fmt=qcow2 cluster_size=65536 ...
```

---

## 5. SSH into the VM

```
$ ssh -i /data/chromiumos/chromite/ssh_keys/testing_rsa \
    -o StrictHostKeyChecking=no -p 9222 root@localhost

amd64-generic ~ #
```

---

## 6. Starting the LLM Server

```
amd64-generic ~ # /usr/local/opt/llm-service/bin/llama-server --model /usr/local/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf --host 0.0.0.0 --port 8080 --threads 4 --ctx-size 2048

register_backend: registered backend CPU (1 devices)
register_device: registered device CPU (Intel Core Processor (Haswell, no TSX))
main: n_parallel is set to auto, using n_parallel = 4 and kv_unified = true
build: 0 (unknown) with Clang 21.0.0 for Linux x86_64 (debug)
system_info: n_threads = 4 (n_threads_batch = 4) / 8 | CPU : SSE3 = 1 | LLAMAFILE = 1 | REPACK = 1

main: loading model
srv    load_model: loading model '/usr/local/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf'
llama_model_loader: loaded meta data with 26 key-value pairs and 339 tensors from ...qwen2.5-1.5b-instruct-q4_k_m.gguf (version GGUF V3 (latest))
llama_model_loader: - kv   2:                               general.name str              = qwen2.5-1.5b-instruct
llama_model_loader: - kv   5:                         general.size_label str              = 1.8B
llama_model_loader: - type  f32:  141 tensors
llama_model_loader: - type q4_K:  169 tensors
llama_model_loader: - type q6_K:   29 tensors
print_info: file type   = Q4_K - Medium
print_info: file size   = 1.04 GiB (5.00 BPW)
print_info: model type  = 1.5B
print_info: model params = 1.78 B
print_info: n_vocab      = 151936
print_info: n_ctx_train  = 32768
load_tensors:   CPU_Mapped model buffer size =  1059.89 MiB
.........................................................................
llama_context: n_ctx         = 2048
llama_context: n_batch       = 2048
llama_context: flash_attn    = auto (set to enabled)
llama_kv_cache: size =   56.00 MiB (2048 cells, 28 layers), K (f16): 28.00 MiB, V (f16): 28.00 MiB
sched_reserve:        CPU compute buffer size =   302.75 MiB
common_init_from_params: warming up the model with an empty run - please wait ...
srv    load_model: initializing slots, n_slots = 4
slot   load_model: id  0 | new slot, n_ctx = 2048
slot   load_model: id  1 | new slot, n_ctx = 2048
slot   load_model: id  2 | new slot, n_ctx = 2048
slot   load_model: id  3 | new slot, n_ctx = 2048
init: chat template, example_format:
  <|im_start|>system\nYou are a helpful assistant<|im_end|>
  <|im_start|>user\nHello<|im_end|>
  <|im_start|>assistant\nHi there<|im_end|>
srv          init: chat template, thinking = 0
main: model loaded
main: server is listening on http://0.0.0.0:8080
main: starting the main loop...
srv  update_slots: all slots are idle
```

### Server log on incoming request

```
srv  params_from_: Chat format: peg-native
slot get_availabl: id  3 | task -1 | selected slot by LRU
slot launch_slot_: id  3 | task 0  | processing task
slot update_slots: id  3 | task 0  | new prompt, n_ctx_slot = 2048, task.n_tokens = 35
slot update_slots: id  3 | task 0  | prompt processing done, n_tokens = 35
slot print_timing: id  3 | task 0  |
prompt eval time =    2198.65 ms /    35 tokens (   62.82 ms per token,    15.92 tokens/s)
       eval time =    2829.77 ms /    34 tokens (   83.23 ms per token,    12.02 tokens/s)
      total time =    5028.41 ms /    69 tokens
slot      release: id  3 | task 0  | stop processing: n_tokens = 68, truncated = 0
srv  update_slots: all slots are idle
srv  log_server_r: done request: POST /v1/chat/completions 127.0.0.1 200

# Second request uses KV cache (prompt cached from first call — much faster prompt eval):
slot get_availabl: id  3 | task -1 | selected slot by LCP similarity, sim_best = 1.000
slot update_slots: id  3 | task 35 | n_past was set to 34 (cache hit)
prompt eval time =      82.35 ms /     1 tokens (   82.35 ms per token,    12.14 tokens/s)
       eval time =    3356.47 ms /    41 tokens (   81.87 ms per token,    12.22 tokens/s)
      total time =    3438.82 ms /    42 tokens
srv  log_server_r: done request: POST /v1/chat/completions 127.0.0.1 200
```

---

## 7. Testing the API

From the host machine:

```
$ curl http://localhost:8080/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"qwen","messages":[{"role":"user","content":"Hello, what are you?"}]}' \
    | python3 -m json.tool

{
    "choices": [
        {
            "finish_reason": "stop",
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "I am Qwen, a large language model created by Alibaba Cloud. I'm here to help you with your questions and provide information on a wide range of topics. How can I assist you today?"
            }
        }
    ],
    "created": 1773359452,
    "model": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
    "object": "chat.completion",
    "usage": {
        "completion_tokens": 41,
        "prompt_tokens": 35,
        "total_tokens": 76
    },
    "timings": {
        "prompt_per_second": 12.14,
        "predicted_per_second": 12.21
    }
}
```

**Success.** The LLM service is running on ChromiumOS and responding correctly at ~12 tokens/second on CPU.
