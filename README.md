# ChromeOS LLM Service

Runs [llama.cpp](https://github.com/ggml-org/llama.cpp) with Qwen2.5-1.5B-Instruct as an offline OpenAI-compatible HTTP API on ChromiumOS.

## What This Does

- Builds `llama-server` (llama.cpp `b8279`) as a ChromiumOS package
- Bundles the Qwen2.5-1.5B-Instruct Q4_K_M model (~1.1GB)
- Exposes an OpenAI-compatible API at `http://localhost:8080`
- Installs into the ChromiumOS dev image partition (`/usr/local`)

## How ChromeOS Build System Works

ChromiumOS uses Portage (Gentoo's package manager). Packages are defined as **ebuilds** in **overlays**. The build flow is:

```
cros build-packages   →   compiles packages into sysroot (/build/<board>/)
cros build-image      →   assembles sysroot into a bootable image
```

### Image Types

| Image | Partition | Virtual package |
|-------|-----------|-----------------|
| Base  | ROOT-A (2GB, read-only) | `virtual/target-os` |
| Dev   | Stateful (`/usr/local`) | `virtual/target-os-dev` |
| Test  | Same as Dev + test tools | `virtual/target-os-test` |

### Why We Use the Dev Image Partition

The ROOT-A partition is only 2GB. The model alone is 1.1GB. Placing `llm-service` in `virtual/target-os-dev` puts it in the **stateful partition** (mounted at `/usr/local` on device), which has plenty of space.

### Overlay Priority

Board overlays (`overlay-amd64-generic`) have higher priority than the base `chromiumos-overlay`. To override a virtual package, use a **higher version number** than upstream:

- Upstream `virtual/target-os`: `1-r6` → we use `2`
- Upstream `virtual/target-os-dev`: `1-r7` → we use `2`

## Files Changed

```
overlay/
├── chromeos-base/llm-service/
│   ├── llm-service-1.0.0.ebuild        # Main package: builds llama.cpp, installs model
│   └── files/
│       ├── llm-service.conf            # Upstart service config
│       ├── llm-service.minijail.conf   # Minijail sandbox config
│       └── llm-service-tmpfiles.conf   # Creates /var/log/llm-service at boot
├── virtual/
│   ├── target-os/target-os-2.ebuild         # Base image virtual (no llm-service)
│   └── target-os-dev/target-os-dev-2.ebuild # Dev image virtual (includes llm-service)
└── metadata/md5-cache/
    ├── chromeos-base/llm-service-1.0.0      # Portage metadata cache
    ├── virtual/target-os-2                   # Portage metadata cache
    └── virtual/target-os-dev-2              # Portage metadata cache
```

### Key Design Decisions

- **`llm-service` in `virtual/target-os-dev`** (not `target-os`): keeps the 1.1GB model out of ROOT-A
- **On-device paths** (everything under `/usr/local/` since it's in dev image):
  - Binary: `/usr/local/opt/llm-service/bin/llama-server`
  - Model:  `/usr/local/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf`
- **`filter-flags`** in ebuild: ChromeOS disables C++ exceptions globally; llama.cpp requires them

## Prerequisites

- ChromiumOS source checked out at `/data/chromiumos`
- Board `amd64-generic` set up (`cros build-packages` run at least once)

## Build Instructions

### 1. Copy overlay files

Copy the `overlay/` directory contents into your board overlay:

```bash
cp -r overlay/* /data/chromiumos/src/overlays/overlay-amd64-generic/
```

### 2. Build the package

```bash
sudo /data/chromiumos/chromite/bin/cros build-packages \
  --board=amd64-generic \
  chromeos-base/llm-service virtual/target-os virtual/target-os-dev
```

> First run takes ~10 minutes (compiles llama.cpp from source + downloads 1.1GB model).
> Subsequent runs use cached binary packages.

### 3. Build the image

```bash
sudo /data/chromiumos/chromite/bin/cros build-image \
  --board=amd64-generic \
  --no-enable-rootfs-verification \
  test
```

## Testing in a VM

### Start the VM

```bash
IMG=$(ls /data/chromiumos/src/build/images/amd64-generic/R148-*/chromiumos_test_image.bin | tail -1)
sudo /data/chromiumos/chromite/bin/cros vm --start \
  --board=amd64-generic \
  --image-path "$IMG" \
  --copy-on-write \
  --ssh-port 9222 \
  --qemu-hostfwd tcp:127.0.0.1:8080-:8080 \
  --qemu-mem 8192 \
  --no-display \
  --wait-for-boot
```

### SSH into the VM

```bash
ssh -i /data/chromiumos/chromite/ssh_keys/testing_rsa \
  -o StrictHostKeyChecking=no \
  -p 9222 root@localhost
```

### Start the LLM server

```bash
/usr/local/opt/llm-service/bin/llama-server \
  --model /usr/local/opt/llm-service/models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
  --host 0.0.0.0 --port 8080 --threads 4 --ctx-size 2048
```

### Test the API (from host machine)

```bash
curl http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Hello, what are you?"}]}' \
  | python3 -m json.tool
```

Expected response:
```json
{
    "choices": [
        {
            "message": {
                "role": "assistant",
                "content": "I am Qwen, a large language model created by Alibaba Cloud..."
            }
        }
    ],
    "model": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
    "usage": {
        "completion_tokens": 41,
        "prompt_tokens": 35,
        "total_tokens": 76
    }
}
```

### Stop the VM

```bash
sudo /data/chromiumos/chromite/bin/cros vm --stop --ssh-port 9222
```

## Performance

Tested on CPU only (no GPU):
- ~12 tokens/second on Intel Haswell (QEMU VM, 8GB RAM)
- Model load time: ~3 seconds

## Known Limitations

- The upstart service config (`llm-service.conf`) lands at `/usr/local/etc/init/` in the dev image, which upstart does not auto-read. Start the server manually as shown above.
- CPU-only inference. GPU support (`GGML_CUDA`, `GGML_VULKAN`) can be enabled in the ebuild's `src_configure()`.
