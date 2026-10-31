# Contracts changelog

Everything in `contracts/` was frozen at gate **G0**. Code must match it exactly.
A change needs an entry below and inspector approval **before** anyone codes against it.

## How to request a change

1. Write the request in your `status/T<n>.md` under "Contract questions" (you cannot edit `contracts/`).
2. T0 adds an entry below with status `proposed` and edits the contract file on `main`.
3. The inspector approves or rejects it, and the status is updated.
4. Affected terminals run `git merge main`.

## Entry template

```
### YYYY-MM-DD — <short title>
- Status: proposed | approved | rejected
- Files: contracts/<file>
- What: <exact change: field, endpoint, enum value…>
- Why: <reason>
- Affected: T1, T2, T3, T4 (who must change code)
- Requested by: T<n> · Approved by: inspector
```

## Entries

### 2026-10-31 — v1.0.0 frozen at G0
- Status: approved by the inspector (G0, 2026-10-31)
- Files: all
- What: first version of openapi.yaml, ws_events.json, message.schema.json, intent.schema.json,
  voice_api.yaml, ocr_api.yaml, adapter_api.yaml, db_schema.sql/.md
- Affected: everyone
