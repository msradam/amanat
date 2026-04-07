# Amanat — Humanitarian Data Governance Agent

A privacy-first AI agent that helps humanitarian NGOs find and fix sensitive data exposure across cloud services.

Built for the [Auth0 "Authorized to Act" Hackathon](https://authorizedtoact.devpost.com/). See the full [Devpost submission](https://devpost.com/software/amanat-data-governance-ai-agent).

---

## How It Works

1. **Authenticate** via Auth0 Universal Login with Guardian MFA
2. **Connect services** via Auth0 Token Vault (OneDrive, Outlook, Slack) — per-service OAuth consent, tokens managed by Auth0
3. **Scan** — the agent calls Microsoft Graph and Slack APIs, runs hybrid PII detection (regex + Granite 4 Micro)
4. **Analyze** — findings evaluated against ICRC Handbook, IASC Guidance, GDPR, and Sphere Standards via BM25 RAG
5. **Remediate** — revoke sharing, redact PII, post alerts; destructive actions require CIBA step-up auth (Guardian push to phone)

## Auth0 Features Used

| Feature | How Amanat Uses It |
|---------|-------------------|
| **Universal Login** | Single sign-on with Guardian MFA push notifications |
| **Token Vault** | Federated token exchange for OneDrive, Slack, Outlook. Per-service scoping. MRRT across My Account API |
| **CIBA** | Guardian push to user's phone before revoking sharing or deleting files. Agent polls until approved |
| **Guardian MFA** | Push notifications for login and CIBA step-up auth |

## Published App

**Live demo:** https://msradam-amanat.hf.space

Uses watsonx.ai to host the same Granite 4 model that runs locally. Auth0 login works. Demo mode returns synthetic data. CIBA works for any user enrolled in Guardian. All synthetic data is [auditable in the repo](demo-data/drive/).

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical breakdown: Auth0 integration, agent pipeline, tool list, PII detection, policy RAG, security controls, and deployment.

## Setup

### Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/)
- [llama.cpp](https://github.com/ggerganov/llama.cpp) with a Granite 4 Micro GGUF model
- Auth0 account (free tier works)

### Install

```bash
git clone https://github.com/msradam/amanat
cd amanat
uv sync
```

### Start the LLM

```bash
llama-server \
  --model /path/to/granite-4-micro.gguf \
  --port 8080 \
  --ctx-size 4096 \
  --jinja
```

### Environment

```bash
cp .env.example .env
```

Fill in `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
OAUTH_AUTH0_CLIENT_ID=your-client-id
OAUTH_AUTH0_CLIENT_SECRET=your-client-secret
OAUTH_AUTH0_DOMAIN=your-tenant.us.auth0.com
OPENAI_API_BASE=http://localhost:8080/v1
OPENAI_API_KEY=llama
CHAINLIT_AUTH_SECRET=your-random-secret  # openssl rand -hex 32
```

### Run

```bash
uv run chainlit run app.py
```

Open `http://localhost:8000`. Log in via Auth0, connect your services, and start scanning.

## Demo Data

All synthetic data lives in [`demo-data/`](demo-data/):

- [`demo-data/drive/`](demo-data/drive/) — OneDrive files (Beneficiary Records, Protection, Biometric Data, Field Operations, Donor Relations, Scanned Documents)
- [`demo-data/slack/`](demo-data/slack/) — Slack messages with PII in public channels
- [`demo-data/outlook/`](demo-data/outlook/) — Outlook emails with beneficiary data

## Project Structure

```
amanat/
  agent.py           # Strands agent, 14 tools, system prompt
  auth.py            # Auth0 Token Vault — federated token exchange
  tools/
    scanner.py       # Tool dispatcher, hybrid PII detection, demo data
    onedrive.py      # Microsoft Graph API
    slack.py         # Slack Web API
    outlook.py       # Outlook / Graph Mail API
    docling_tool.py  # Document parsing (PDF/DOCX OCR)
  knowledge/
    policies.py      # BM25 RAG over 1,059 policy chunks
    rules.py         # Governance rules engine
app.py               # Chainlit UI — OAuth, CIBA gate, audit logging
demo-data/           # Synthetic humanitarian data
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Auth | Auth0 Universal Login, Token Vault, CIBA, Guardian MFA |
| LLM | IBM Granite 4 Micro (Apache 2.0, ISO 42001) |
| Agent | Strands Agents SDK |
| Document parsing | IBM Docling + granite-docling-258M |
| Web UI | Chainlit |
| APIs | Microsoft Graph, Slack Web API |
| Language | Python 3.13 |

## The Name

*Amanat* (Arabic: trust, stewardship) — what is entrusted to you must be protected and returned faithfully.

## License

MIT

Logo: "Cheerful File" by [Kokota](https://thenounproject.com/kokota/) — CC BY 3.0
