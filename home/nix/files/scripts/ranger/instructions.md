# Ranger Prototype: Agent Implementation Instructions

You are an expert Rust AI agent tasked with building the "Ranger" prototype—a 100% Rust, cross-platform AI inference engine using the Burn framework.

## Core Engineering Directives

You must strictly adhere to the following workflow for every task:

1. **Iterative Validation:** After completing any small sub-task or component, you MUST run:
   - `cargo check` to ensure type safety and compilation.
   - `cargo clippy --workspace --all-targets -- -D warnings` to enforce Rust best practices.
   - `cargo test --workspace` to ensure no regressions.
     Do not proceed to the next task until these commands pass successfully.

2. **Test-Driven:** Write unit tests for as much code as possible.

- Every new module should have an accompanying `#[cfg(test)] mod tests { ... }` block to verify its isolated behavior.
- Mock external dependencies (like HF Hub or the file system) where appropriate.

3. **Architecture & Modularity:**
   - Keep the code DRY (Don't Repeat Yourself).
   - Use idiomatic Rust modules (`mod.rs` or directory modules).
   - **Local Crates:** Extract large, logically grouped components into local crates within the workspace.
   - Structure the project into:
     - `ranger` (CLI/main)
     - `ranger-core` (engine/quantization)
     - `ranger-api` (axum server)
     - `ranger-tui` (ratatui interface)

4. **Codebase Review & Reuse:**
   - **Crucial Requirement:** Before implementing a new module, you MUST review the existing prototypes at;
   - `home/nix/files/scripts/burn-launcher`
   - home/nix/files/scripts/burn-lm-launcher`
   - Identify reusable components, particularly around hardware detection (VRAM/RAM), HuggingFace downloading, TUI layouts, and Axum streaming setups.
   - The goal is to combine the best ideas into "Ranger" rather than rewriting everything from scratch unless needed.
   - **STRICT ANTI-PATTERNS (DO NOT DO THIS):**
     - **DO NOT** use `burn-lm` crates. They lack "day-0" support for cutting-edge features.
     - **DO NOT** use ONNX generated graphs (`burn-onnx`). They create static, inflexible KV caches that break dynamic text streaming on WebGPU.
   - **THE MANDATED PATH:** You MUST use **Native Burn Architecture + SafeTensors**.
   - This means manually writing the `burn::module::Module` traits for Gemma 4 (specifically the E2B/E4B dense models) in Rust and loading the raw `.safetensors` from HuggingFace.
   - Heavily referencing the approach taken in the `burn-launcher` prototype.

## Architecture Overview

- **Language:** 100% Rust
- **Inference Engine:** `burn` + `burn-wgpu` (CubeCL)
- **Target Models (Strict Scope):** Only the following Gemma 4 Dense models are supported for this prototype. (Do NOT implement MoE or 26B/31B variants yet):
  - `gemma-4-e4b-it` (Google Gemma 4 E4B Instruct)
  - `gemma-4-e4b` (Google Gemma 4 E4B Base)
  - `gemma-4-e2b-it` (Google Gemma 4 E2B Instruct)
  - `gemma-4-e2b` (Google Gemma 4 E2B Base)
- **Configuration:** Models read from a YAML file.
- **API Server:** `axum` + `tokio` (OpenAI-compatible, SSE streaming, FIFO Queue)
- **TUI:** `ratatui` + `crossterm`
- **Pipeline:** SafeTensors Download -> Burn PTQ (Int8 Quantization) -> `.mpk` Caching -> mmap Warm Boot.

## Implementation Phases

### Phase 1: Workspace Setup & Scaffolding

- **Task 1.1:** Initialize the local crates (`ranger`, `ranger-core`, `ranger-api`, `ranger-tui`) inside `/boot/nixos/nix-config/home/nix/files/scripts/ranger/`.
- **Task 1.2:** Add the new crates to the main workspace `Cargo.toml`.
- **Task 1.3:** Set up `Cargo.toml` dependencies, utilizing workspace inherited dependencies.
- **Validation:** Run `cargo check --workspace`.

### Phase 2: Configuration & Hardware Monitoring (`ranger-core`)

- **Task 2.1:** Define hardware abstraction structs (VRAM/RAM detection).
- **Task 2.2:** Implement strict constraint checking (block loading if model exceeds VRAM). Support UI hooks for System RAM and GPU VRAM graphing.
- **Task 2.3:** Implement a YAML-based Model Registry parser (strictly for Gemma 4 variants).
- **Validation:** Write unit tests. Run `cargo clippy` and `cargo test`.

### Phase 3: The Inference Pipeline (`ranger-core`)

- **Task 3.1:** Implement the HuggingFace SafeTensors downloader (Cold Boot).
- **Task 3.2:** Scaffold the Burn `Module` traits specifically for **Gemma 4**.
- **Task 3.3:** Implement Post-Training Quantization (PTQ Int8) utilizing Burn 0.19+ native quantization features. Serialize the quantized model to `.mpk` (MessagePack).
- **Task 3.4:** Implement Warm Boot logic to mmap `.mpk` files directly into the `wgpu` backend.
- **Validation:** Write unit tests for caching logic. Run `cargo check`, `clippy`, and `test`.

### Phase 4: API Server & FIFO Queue (`ranger-api`)

- **Task 4.1:** Set up `axum` routes for `/v1/models` and `/v1/chat/completions`.
- **Task 4.2:** Implement a FIFO execution scheduler using `tokio::sync::mpsc`. The API handlers push requests into the channel, and a single background worker runs the Gemma 4 forward pass.
- **Task 4.3:** Implement SSE streaming to return tokens to the API client as they are generated by the worker.
- **Validation:** Write unit tests for the FIFO queue using mock channels.

### Phase 5: Interface & Orchestration (`ranger-tui` & `ranger`)

- **Task 5.1:** Implement the `ratatui` interface. The TUI must visualize System RAM and GPU VRAM estimates to prevent OOM errors.
- **Task 5.2:** Implement TUI-to-API communication. The TUI should act as an HTTP client to the local Axum server to test the full pipeline, while reading system metrics via shared state.
- **Task 5.3:** Wire the CLI entrypoint to bootstrap the Engine, spawn the API Server on a background task, and launch the TUI.
- **Validation:** Run `cargo check`, `clippy`, and `test` across the workspace.

Remember: Do not rush. Take it one task at a time, strictly following the validation step before moving on. Provide a brief explanation of your intent before executing any commands.

## Additional Project Guidelines

- **Pre-commit Hooks:** This project uses pre-commit hooks. Ensure pre-commit hooks pass before considering a task complete and moving on to the next one.
- **Spell Checking:** Spelling words should go into `/boot/nixos/nix-config/project-words.txt`. If you need to exclude a path for spelling, update `/boot/nixos/nix-config/.cspell.yaml`.
- **Committing Changes:** Run `git add --all` and `git commit -m "feat: Complete Task x.x"` (replacing `x.x` with the task number) for each task completed.
