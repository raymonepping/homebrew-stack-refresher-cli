# 🛡️ Vault Radar Agent — Containerized

A simple GitHub Action workflow using a containerized Vault Radar CLI to scan your codebase for secrets, sensitive data, and PII — no install required.

This repository demonstrates how to:
- Run Vault Radar as a Docker container inside CI pipelines
- Automatically fail builds on high/critical findings
- Archive scan results as build artifacts
- Output scan summary to the GitHub Actions UI

---

## 🚀 How It Works

The included workflow (`.github/workflows/vault-radar.yml`) performs the following:

1. ✅ **Checks out the repo**
2. 🐳 **Runs the Vault Radar CLI container**
3. 📊 **Scans the entire folder** for secrets and PII
4. 📄 **Exports results to `scan_file.csv`**
5. 📦 **Archives the scan as a GitHub Action artifact**
6. 🔔 **Blocks the build on high/critical findings**

---

## 📁 Folder Structure

```text
.
├── .github/
│   └── workflows/
│       └── vault-radar.yml   # GitHub Actions workflow
├── findings/
│   └── scan_file.csv         # Vault Radar scan results (if present)
├── README.md                 # You're here!
└── LICENSE                   # GPLv3 License
```

---

## 🧪 Example Output

Scan summary is written to the GitHub Actions UI:

ℹ️ Low severity findings detected
⚠️ Medium severity findings detected
❌ High or critical severity findings detected. Blocking the build.
📝 Scan results saved to findings/scan_file.csv
GitHub will also show annotations inline if medium/high findings are detected.

---

## 🔐 Secrets Required

To authenticate with HCP Vault Radar, add the following to your repository secrets:

- HCP_CLIENT_ID
- HCP_CLIENT_SECRET
- HCP_PROJECT_ID

---

## 🧰 Usage
Fork this repo or copy the .github/workflows/vault-radar.yml into your own repo, and add your secrets via GitHub settings.

Want to change severity thresholds? Just update the grep logic in the workflow!

## 📝 License

This project is licensed under GPLv3.

---

🤖 Powered By;
HashiCorp Vault Radar + GitHub Actions + Containerization = effortless security hygiene.

> Because automation should automate itself.