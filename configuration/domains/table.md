
---

## 📚 Domain Matrix

Below are the domains covered. Each domain lists must, should, and could tools with short rationales.


<details>
<summary><strong>Terminal & UX — v2.0.0</strong></summary>

Terminal, shell, and UX tools for local productivity and navigation.

| Level | Tool | Rationale |
|------|------|-----------|
| must | bat | Modern 'cat' with syntax highlighting and pager integration. |
| must | eza | Modern 'ls' (exa fork) with icons/tree. |
| must | fzf | Fuzzy finder used across workflows. |
| must | powerlevel10k | Fast, modern Zsh prompt enhancing productivity. |
| must | ripgrep | Fast search tool replacing grep. |
| must | tmux | Terminal multiplexer for panes, sessions, and remote safety. |
| must | zsh | Primary shell; baseline for Zsh-based UX and plugins. |
| should | atuin | Shell history with sync and search. |
| should | bash-completion | Programmable completion for bash. |
| should | fd | Modern 'find' with sane defaults and speed. |
| should | thefuck | Corrects mistyped console commands. |
| should | tldr | Simplified man pages with examples. |
| should | zoxide | Smarter 'cd' based on frecency. |
| could | dust | Disk usage viewer, like du but better. |
| could | figlet | ASCII banners for fun or section headers. |
| could | gum | Pretty TUI prompts; enhances UX if available. |
| could | lolcat | Rainbow styling for fun, optional flair. |
| could | procs | Modern replacement for ps. |
| could | raycast | macOS launcher to trigger scripts quickly. |
| could | starship | Cross-shell prompt written in Rust. |
| could | warp | Next-gen terminal (macOS). |
| could | zsh-autosuggestions | Suggests completions as you type in Zsh. |
| could | zsh-syntax-highlighting | Syntax highlighting for Zsh. |

</details>


<details>
<summary><strong>SSH & Key Management — v1.0.0</strong></summary>

SSH clients, agents, auditing, and smartcard support.

| Level | Tool | Rationale |
|------|------|-----------|
| must | openssh | Standard SSH client/server; baseline for remote access. |
| should | gh-key-upload | Uploads local SSH keys to GitHub for easier repo access. |
| should | key-rotation-helper | Automates SSH key rotation to reduce risk of stale credentials. |
| should | ssh-audit | Analyzes SSH server config for weak algorithms and settings. |
| could | age | Simple, modern file encryption tool; complements SSH workflows. |

</details>


<details>
<summary><strong>Git & Source Control — v1.0.0</strong></summary>

Source control and developer Git workflows.

| Level | Tool | Rationale |
|------|------|-----------|
| must | delta | Improved diff viewer for Git with syntax highlighting. |
| must | gh | GitHub CLI for managing repos, PRs, and issues directly. |
| must | git | Core version control system; foundation for all workflows. |
| must | pre-commit | Framework for managing Git hooks; enforces checks pre-push. |
| should | git-secrets | Prevents committing AWS keys and other sensitive credentials. |
| should | gitleaks | Scans repos for hardcoded secrets and sensitive data. |
| should | lazygit | Terminal UI for Git; simplifies commits, merges, and rebases. |
| could | git-cliff | Generates changelogs from conventional commits. |
| could | gpg | Enables commit signing and verification of contributors. |

</details>


<details>
<summary><strong>Code & Dev Tools — v1.0.0</strong></summary>

Editors, toolchain managers, and code helpers for local development.

| Level | Tool | Rationale |
|------|------|-----------|
| must | direnv | Manages environment variables per project; integrates with shells. |
| must | just | Command runner; a modern replacement for Makefiles. |
| must | shellcheck | Static analysis for shell scripts; finds bugs and style issues. |
| should | asdf | Runtime version manager for multiple languages and tools. |
| should | eslint | JavaScript/TypeScript linter; enforces code quality rules. |
| should | jsonlint | Validator and formatter for JSON files. |
| should | prettier | Code formatter for JavaScript, JSON, Markdown, and more. |
| should | pylint | Linter for Python code, enforcing style and best practices. |
| should | vscode | Widely used IDE with rich extensions and debugging support. |
| should | yamllint | Linter for YAML files to catch errors and enforce style. |
| could | black | Opinionated Python code formatter; enforces consistency. |
| could | commitizen | Helps enforce conventional commit messages for automation. |
| could | hadolint | Linter for Dockerfiles; prevents common mistakes. |
| could | lefthook | Fast, polyglot Git hooks manager for projects. |
| could | mise | Alternative runtime version manager, faster and simpler than asdf. |
| could | nvm | Node.js version manager; useful for JavaScript projects. |
| could | pyenv | Python version manager; allows multiple runtime installations. |
| could | shfmt | Formatter for shell scripts; ensures consistent style. |

</details>


<details>
<summary><strong>Containers & Runtimes — v1.0.0</strong></summary>

Containerization tools and runtimes for application deployment.

| Level | Tool | Rationale |
|------|------|-----------|
| must | colima | Lightweight VM for Docker/Podman on macOS; provides container runtime layer. |
| must | compose | Defines and runs multi-container applications declaratively. |
| must | nomad | HashiCorp scheduler for container and non-container workloads. |
| should | buildah | OCI-compliant tool to build container images without Docker daemon. |
| should | skopeo | Utility for copying, inspecting, and signing container images. |
| should | trivy | Security scanner for container images and filesystem vulnerabilities. |
| could | ctop | Top-like interface for container monitoring. |
| could | dive | Image analyzer for understanding Docker image layers. |
| could | docker-slim | Optimizer that reduces image size and attack surface. |
| could | grype | Vulnerability scanner for container images using SBOMs. |
| could | syft | Generates SBOMs (Software Bill of Materials) from container images. |

</details>


<details>
<summary><strong>Kubernetes (Local Dev) — v1.0.0</strong></summary>

Kubernetes client tooling and cluster interaction UX.

| Level | Tool | Rationale |
|------|------|-----------|
| must | helm | Package manager for Kubernetes applications using charts. |
| must | kubectl | Primary CLI to interact with Kubernetes clusters. |
| should | k9s | TUI for managing Kubernetes resources interactively. |
| could | kubectx | Simplifies context switching between Kubernetes clusters. |
| could | kubens | Quickly switch between Kubernetes namespaces. |

</details>


<details>
<summary><strong>Secrets & Certs — v1.0.0</strong></summary>

Secret management and PKI tooling.

| Level | Tool | Rationale |
|------|------|-----------|
| must | sops | Encrypts/decrypts YAML, JSON, and other config files for GitOps. |
| must | vault | Secret management, encryption-as-a-service, and dynamic credentials. |
| should | mkcert | Local CA and HTTPS certificate generator for development. |
| should | vault-radar | Scans repos and containers for leaked secrets using Vault policies. |
| could | 1password-cli | CLI integration with 1Password for secret retrieval and automation. |

</details>


<details>
<summary><strong>Observability & Logs — v1.0.0</strong></summary>

Local system insight, metrics, and log triage tools.

| Level | Tool | Rationale |
|------|------|-----------|
| must | bottom | Resource monitor with modern TUI for system observability. |
| must | jq | JSON processor; essential for log and API parsing. |
| must | lnav | Log file navigator; interactive searching and filtering of logs. |
| should | fx | Interactive JSON viewer and explorer. |
| should | stern | Streams Kubernetes pod logs with color and regex filters. |
| should | yq | YAML processor, complementary to jq for config and logs. |
| could | btop | Advanced resource monitor with rich visualization. |
| could | duf | Disk usage/free space analyzer with human-friendly TUI. |
| could | glow | Terminal markdown reader for viewing docs inline. |
| could | gping | Ping tool with live graphs to visualize latency. |
| could | htop | Classic interactive process viewer. |
| could | httpie | User-friendly HTTP client for testing APIs. |
| could | logrotate | Manages rotating and compressing system logs. |
| could | viddy | Modern watch command replacement for monitoring outputs. |

</details>


<details>
<summary><strong>Infrastructure as Code — v1.0.0</strong></summary>

Infrastructure as Code authoring, validation, and builds.

| Level | Tool | Rationale |
|------|------|-----------|
| must | packer | Builds machine and container images in a repeatable way. |
| must | terraform | Core IaC tool for provisioning infrastructure across providers. |
| must | tflint | Linter for Terraform configurations; enforces standards and prevents errors. |
| should | checkov | Static analysis for IaC security across Terraform, Kubernetes, and more. |
| should | terragrunt | Wrapper for Terraform that adds workflow improvements and DRY configs. |
| should | tfsec | Security scanner for Terraform code. |
| could | consul | Service discovery and configuration; complements IaC with runtime services. |
| could | terraform-docs | Generates documentation from Terraform modules. |
| could | tfenv | Manages multiple Terraform versions easily. |

</details>


<details>
<summary><strong>Automation & Scheduling — v1.0.0</strong></summary>

Local automation, build orchestrators, and CLI glue.

| Level | Tool | Rationale |
|------|------|-----------|
| must | entr | Lightweight file-watcher for triggering rebuilds or reloads. |
| must | parallel | Run jobs in parallel across multiple CPU cores; essential for scaling scripts. |
| must | watchexec | Runs commands when files change; ideal for live reloads and automation. |
| should | cron | Classic job scheduler for periodic tasks. |
| should | hyperfine | Benchmark command-line programs with statistical output. |
| should | tmuxinator | Manages complex tmux session setups for automation. |
| could | at | One-time job scheduler for deferred execution. |
| could | tmux-resurrect | Restores tmux sessions after restart; improves workflow continuity. |

</details>


<details>
<summary><strong>Bonus Tools (My Own Brews) — v1.0.1</strong></summary>

Bonus domain with my own CLI tools published via Homebrew. These are opinionated helpers I maintain myself, grouped as must, should, and could.

| Level | Tool | Rationale | Install |
|------|------|-----------|---------|
| must | brew-brain-cli | Tracks and compares expected vs installed brews; renders Markdown reports. | brew install brew-brain-cli |
| must | bump-version-cli | Handles semantic versioning without sed headaches; supports patch, minor, major bumps. | brew install bump-version-cli |
| must | commit-gh-cli | Automates the PR process with version bump, commit, changelog, push, and PR creation. | brew install commit-gh-cli |
| must | folder-tree-cli | Generates clean folder trees in Markdown; perfect for docs and audits. | brew install folder-tree-cli |
| must | radar-scan-cli | Scans folders or Docker images for secrets using Vault Radar; local or GitHub workflow. | brew install radar-scan-cli |
| must | sanity-check-cli | Runs all checks across Bash, Python, Node, and Terraform; outputs sanity_check.md. | brew install sanity-check-cli |
| must | slim-container-cli | Optimizes and scans Docker images with DockerSlim, Trivy, Grype, Dockle, and Dive. | brew install slim-container-cli |
| should | repository-audit-cli | Audits repos for insights, tag checks, and uncommitted changes. | brew install repository-audit-cli |
| should | self-doc-gen-cli | Automatically generates clean Markdown documentation from Bash scripts. | brew install self-doc-gen-cli |
| could | export-docker-image-cli | Lists and exports Docker images to JSON/Markdown; helps with hygiene and reporting. | brew install export-docker-image-cli |
| could | radar-love-cli | Simulates secret leaks across multiple languages for Vault Radar demos. | brew install radar-love-cli |
| could | repository-backup-cli | Backs up GitHub repos with smart modular commands: backup, recover, prune, summary. | brew install raymonepping/repository-backup-cli/repository-backup-cli |
| could | repository-export-cli | Exports all GitHub repos to Markdown, JSON, or CSV with stats and summaries. | brew install repository-export-cli |

</details>

---

