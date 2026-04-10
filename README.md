# terraform-py-provisioner

A professional-grade Infrastructure-as-Code (IaC) suite designed to provision, manage, and orchestrate AWS resources. This repository combines the declarative power of **Terraform** with the dynamic flexibility of **Python** to ensure a "full-proof" deployment pipeline.

## 🚀 Overview
Unlike standard setups, this project uses Python as an orchestration layer to handle complex logic—such as dynamic variable injection and pre-deployment validation—while Terraform maintains the infrastructure state.

---

## 🛠 Tech Stack
* **Infrastructure:** Terraform (HCL)
* **Orchestration:** Python 3.x
* **Package Manager:** uv
* **Cloud Provider:** AWS

---

## 📋 Prerequisites
Before you begin, ensure you have the following installed:
1. **AWS CLI:** [Install AWS CLI](https://aws.amazon.com/cli/)
2. **Terraform CLI:** [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
3. **Python 3.9+:** [Install Python](https://www.python.org/downloads/)
4. **uv:** [Install uv](https://github.com/astral-sh/uv)

---

## 🚦 Getting Started

### 1. AWS Configuration
Configure your local machine with your AWS credentials.
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region, and Output format.
```

### 2. Python Project Setup
We use `uv` to manage this project as a synchronized workspace.

```bash
# Initialize the project (creates pyproject.toml and .python-version)
uv init

# Sync the environment
uv sync

### 3. Running the Provisioner
Once configured, use the Python orchestration script to manage your infrastructure.
```bash
uv run main.py
```

---

## 📝 License
This project is licensed under the MIT License.
