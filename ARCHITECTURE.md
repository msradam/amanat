# Amanat Architecture

## Overview

Amanat is an AI agent that scans OneDrive, Slack, and Outlook for sensitive humanitarian data, evaluates findings against policy frameworks, and takes remediation actions. Auth0 handles identity and authorization. IBM Granite 4 Micro runs locally for data privacy.

## Auth0 Integration

### Authentication Flow

1. User logs in via **Auth0 Universal Login** with **Guardian MFA** (push notification)
2. Chainlit's OAuth callback receives an access token and refresh token
3. Refresh token stored in session for Token Vault exchanges

### Token Vault (Connected Accounts)

Each external service is connected separately via the Connected Accounts flow:

```
POST /oauth/token
grant_type=urn:auth0:params:oauth:grant-type:token-exchange:federated-connection-access-token
subject_token={refresh_token}
subject_token_type=urn:ietf:params:oauth:token-type:refresh_token
requested_token_type=http://auth0.com/oauth/token-type/federated-connection-access-token
connection=microsoft-graph
```

A single **Multi-Resource Refresh Token (MRRT)** works across the My Account API and all connected services. Token expiry is tracked via `TokenInfo.is_expired()` with a 60-second buffer, triggering automatic re-exchange.

**Per-service scoping:**

| Service | Connection | Scopes |
|---------|-----------|--------|
| OneDrive + Outlook | `microsoft-graph` | `Files.Read`, `Files.ReadWrite`, `Mail.Read`, `Mail.Send`, `offline_access` |
| Slack (read) | `sign-in-with-slack` | `channels:read`, `channels:history`, `search:read` |
| Slack (write) | Bot token | `chat:write` (separate credential, posts as "Amanat") |

**Implementation:** `amanat/auth.py` (TokenInfo, UserSession, Auth0TokenVault classes)

### CIBA (Client-Initiated Backchannel Authentication)

Any call to `revoke_sharing` or `delete_file` triggers step-up auth:

1. Agent calls `POST /bc-authorize` with the user's `sub`, a binding message describing the action, and `scope=openid`
2. Auth0 sends a Guardian push notification to the user's phone
3. Agent polls `POST /oauth/token` with `grant_type=urn:openid:params:grant-type:ciba` and the `auth_req_id`
4. On approval, agent receives a CIBA token and proceeds with the action
5. On denial or timeout, action is cancelled

Falls back to in-UI Approve/Deny dialog if CIBA is unavailable (user not enrolled in Guardian).

**Implementation:** `app.py`, `before_tool` hook in the `on_message` handler

## Agent Architecture

### Runtime Pipeline

```
User Query
    → Chainlit Web UI (app.py)
        → System prompt built (_build_system_prompt)
        → Strands Agent created (create_agent)
            → IBM Granite 4 Micro (llama-server or watsonx)
                → Tool call decision
                    → execute_tool (scanner.py)
                        → Live API (Token Vault token) or Demo data
                    → Result returned to agent
                → Agent generates response
        → Response displayed in chat
```

### Components

| Layer | File | Role |
|-------|------|------|
| **Web UI** | `app.py` | Chainlit OAuth, chat profiles, Strands hooks (BeforeToolCall/AfterToolCall), CIBA gate, audit logging |
| **Agent** | `amanat/agent.py` | System prompt, 14 @tool definitions, create_model (llama-server/watsonx/OpenRouter), create_agent |
| **Auth** | `amanat/auth.py` | Auth0TokenVault class, CONNECTIONS dict, TokenInfo with expiry, federated token exchange |
| **Tool dispatch** | `amanat/tools/scanner.py` | execute_tool router, demo data (DEMO_FILES, DEMO_MESSAGES), hybrid PII detection, redaction |
| **OneDrive** | `amanat/tools/onedrive.py` | Microsoft Graph API: scan, check sharing, revoke, download, delete, redact+upload |
| **Slack** | `amanat/tools/slack.py` | Slack Web API: search messages, scan channels, scan file attachments, notify channel |
| **Outlook** | `amanat/tools/outlook.py` | Microsoft Graph Mail API: search emails, send alert emails |
| **Document parsing** | `amanat/tools/docling_tool.py` | IBM Docling + granite-docling-258M for OCR on scanned PDFs |
| **Policy RAG** | `amanat/knowledge/policies.py` | BM25 retrieval over 1,059 chunks from ICRC/IASC/GDPR/Sphere PDFs |
| **Rules engine** | `amanat/knowledge/rules.py` | Deterministic policy evaluation (sharing rules, consent, retention) |

### Tool List (14 tools)

| Tool | Service | Action |
|------|---------|--------|
| `scan_files` | OneDrive | Recursive folder scan, PII detection, sharing check |
| `search_messages` | Slack/Outlook | Search messages for PII patterns |
| `detect_pii` | OneDrive | Deep PII scan on a single file |
| `check_sharing` | OneDrive | Check file permissions and sharing links |
| `revoke_sharing` | OneDrive | Remove public/anonymous sharing links (CIBA-gated) |
| `download_file` | OneDrive | Download file to local storage |
| `delete_file` | OneDrive | Move to trash, auto-downloads first (CIBA-gated) |
| `redact_file` | OneDrive | Replace PII with category labels, upload clean copy |
| `retention_scan` | OneDrive | Flag files exceeding retention periods |
| `generate_dpia` | Local | Generate Data Protection Impact Assessment |
| `check_consent` | Local | Check consent documentation status |
| `notify_channel` | Slack | Post data protection alert to a channel (bot token) |
| `send_email` | Outlook | Send alert email via Graph API |
| `parse_document` | Local | OCR + PII scan on uploaded documents via Docling |

## PII Detection

Two-layer hybrid approach:

**Layer 1 (Regex):** Deterministic patterns for phone numbers, emails, case IDs (WAQ-26CNNNNN), GPS coordinates, medical terms, ethnic/religious identifiers. Zero false negatives on known patterns.

**Layer 2 (LLM):** Granite 4 Micro extracts contextual PII: names in any script, implicit identifiers ("the 15-year-old in Vakwa Shelter"), age+location combos. Catches what regex cannot.

**Implementation:** `detect_pii_in_text()` in `amanat/tools/scanner.py`

## Policy RAG

1. Source PDFs (17.3 MB): ICRC Handbook, IASC Guidance, GDPR, Sphere Handbook
2. Preprocessed with IBM Docling into 1,059 text chunks (`policy_chunks.json`)
3. BM25 ranking via `rank_bm25` at query time
4. Top 5 chunks injected in Granite's native `<documents>` format

**Implementation:** `amanat/knowledge/policies.py`

## Security Controls

| Control | Implementation |
|---------|---------------|
| Local LLM | Granite 4 Micro via llama-server. No cloud API calls for data analysis |
| PII redaction | `redact_pii_in_text()` replaces PII with category labels during redaction and Slack scanning |
| Encrypted audit | Fernet encryption, PBKDF2 key derivation (SHA256, 480K iterations) |
| Token isolation | Auth0 Token Vault. Per-service tokens. Agent never stores raw OAuth credentials |
| CIBA step-up | Guardian push notification before revoke/delete via `POST /bc-authorize` |
| Download before delete | `delete_file` auto-downloads locally before trashing |
| Session wipe | Scan results, messages, Token Vault session cleared on chat end |

## Deployment

**Local (video demo):** llama-server + Chainlit on localhost. Full tool calling with Granite 4 Micro.

**Published app (HF Space):** IBM watsonx.ai hosts the same Granite 4 model. Identical architecture (Strands agent, same tools, same system prompt). Demo mode returns synthetic data. CIBA works for any user enrolled in Guardian.

## Demo Data

All synthetic data is in [`demo-data/`](https://github.com/msradam/amanat/tree/main/demo-data):

- `demo-data/drive/` — OneDrive files organized by folder (Beneficiary Records, Protection, Biometric Data, Field Operations, Donor Relations, Scanned Documents)
- `demo-data/slack/messages.md` — Slack channel messages with PII violations
- `demo-data/outlook/messages.md` — Outlook emails with beneficiary data sent externally

## Licenses

| Component | License |
|-----------|---------|
| Granite 4 Micro | Apache 2.0 (ISO 42001 certified) |
| IBM Docling | MIT |
| granite-docling-258M | Apache 2.0 |
| llama.cpp | MIT |
| Strands Agents SDK | Apache 2.0 |
| Amanat | MIT |
