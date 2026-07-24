# 🚀 Opencode Configuration Repository

A personal workspace setup for [Opencode](https://opencode.ai) — an AI-powered development environment powered by Claude Code.

---

## 🖥️ System Specifications

### Hardware
| Component | Specification |
|-----------|---------------|
| **CPU** | Intel Core i9-13950HX (24 cores, 32 logical processors) |
| **GPU** | NVIDIA GeForce RTX 4070 Laptop GPU |
| **RAM** | 32 GB |
| **System Model** | Predator PH16-71 |

---

## 📁 Repository Overview

This repository stores your Opencode configuration and workspace settings, including:

### Core Configuration Files
- `opencode.json` / `opencode.jsonc` — Main Opencode configuration with model definitions and API endpoints
- `AGENTS.md` — Workspace operations standards and protocols

### Directories
| Directory | Purpose |
|-----------|---------|
| `agents/` | Custom agent definitions and configurations |
| `skills/` | Specialized skills for specific tasks (code review, testing, deployment, etc.) |
| `prompts/` | Prompt templates for minimal context operations |
| `commands/` | Available command macros and shortcuts |
| `plugins/` | Installed plugin extensions |
| `projects/` | Project-specific configurations |

---

## 🤖 Model Configuration

### Primary Model: Qwen3.5-4B-Claude-4.6-Opus Reasoning Distilled v2
**API Identifier**: `qwen3.5-4b-claude-4.6-opus-reasoning-distilled-v2`

#### Summary Overview
| Property | Value |
|----------|-------|
| **Model Name** | Qwen3.5 4B |
| **Estimated Memory Usage** | GPU: 4.46 GB | Total: 4.46 GB |
| **Context Length** | 96,000 tokens |
| **Max Supported Context** | 262,144 tokens |
| **GPU Offload Level** | 32 (Full GPU) |

#### Inference Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Temperature | 0.8 | Sampling temperature for creativity vs determinism |
| Top-P | 0.85 | Nucleus sampling probability |
| Top-K | 40 | Number of tokens to consider at each step |
| Min-P | 0.05 | Minimum token probability filter |
| Repeat Penalty | 1.1 | Penalty for repeating sequences |

#### Architecture & Performance Settings
| Setting | Value | Purpose |
|---------|-------|--------|
| CPU Thread Pool Size | 16 | Parallel processing threads |
| Evaluation Batch Size | 1024 | Batch size for evaluation |
| Physical Batch Size | 512 | Batch size for inference |
| Max Concurrent Predictions | 3 | Concurrency limit |
| Flash Attention | ✅ Enabled | Optimized attention kernel |
| Unified KV Cache | ✅ Enabled | Shared key-value cache |
| Context Checkpoints | 512 | KV cache checkpointing interval |

#### Memory Management Settings
| Setting | Value | Description |
|---------|-------|-------------|
| Offload KV Cache to GPU | ✅ Enabled | Uses GPU for KV cache storage |
| Keep Model in Memory | ✅ Enabled | Retains model in RAM when idle |
| Try mmap | ✅ Enabled | Mmap pages for memory efficiency |
| K-V Cache Quantization | Q8_0 | 8-bit quantization of caches |

#### Advanced Settings
| Setting | Value | Description |
|---------|-------|-------------|
| Speculative Decoding | Off | Disabled |
| Chat Template | None | Not configured |
| RoPE Frequency Base | Auto | Dynamic base frequency |
| RoPE Frequency Scale | Auto | Dynamic scale factor |
| Reasoning Budget Message | None | Not set |

---

### Additional Models Available
| Model | Context | Output | Role |
|-------|---------|--------|------|
| Qwen3.5-4B-Claude-4.6-Opus | 96K | 16K | Primary reasoning assistant |
| Empero-Qwythos-9B | 80K | 24K | Large language capabilities |
| Bonsai-27b-q1_0-gguf | 72K | 8.2K | Compact GGUF model |

---

## ⚙️ Configuration Features

### Compilation Settings
- **Auto-compaction**: Enabled
- **Token retention**: 20,000 recent tokens preserved
- **Reserved tokens**: 8,000 for ongoing context

### API Endpoint
```
Base URL: http://192.168.0.246:1234/v1
API Key: local-key
Timeout: 6 seconds (with 6s chunk timeout)
```

---

## 🎯 Usage

### Commands Available
```powershell
# View configuration help
cd .. && opencode --help

# List available agents
opencode agents list

# Manage skills
opencode skills install <skill-name>
opencode skills list
```

---

## 🛡️ Security Notes

This repository contains **local development settings** only:
- ✅ Local LM Studio endpoint (no cloud API keys exposed)
- ✅ Personal model configurations
- ⚠️ Avoid committing secrets or credentials to external repositories

---

## 🔧 Dependencies & Tools

### Node.js Environment
```powershell
node -v  # Verify installation
```

### Git Repository
This workspace is tracked in Git with:
- `.gitignore` — Excludes node_modules and temporary files
- Standard git workflows supported

---

## 📚 Documentation

| Document | Location |
|----------|----------|
| System Specs | `gpu.txt`, `mem.txt` |
| Agent Standards | `AGENTS.md` |
| Model Reference | `opencode.json` |
| Skill Library | `skills/` directory |

---

## 🎨 About This Machine

**Predator PH16-71** is a high-performance gaming laptop designed for:
- Heavy local LLM inference (32GB RAM enables larger models)
- RTX 4070 GPU accelerates on-device generation
- i9-13950HX delivers sustained performance for long sessions
- Ideal for development, prototyping, and experimentation

---

*Configuration last updated: Sat Jul 25, 2026*
