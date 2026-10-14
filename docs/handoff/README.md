# Handoff documents

This directory is where the **authoritative product/delivery handoff** lives. Everything else in
`docs/` was written *in the absence of it* and is marked as such.

## Why this directory exists

Four working sessions were told a "v0.2 prototype / development handoff" existed, and none of them
could find it. `ARCHITECTURE.md`, `supabase/README.md` and `DEVELOPMENT_STATUS.md` all carry
variants of the same caveat: *"exact rules from the approved prototype are still unavailable"*. The
schema, the privacy rules, the screens and
[`PRODUCT_SPEC.md`](../PRODUCT_SPEC.md) were therefore **inferred from standard Flutter/Supabase
practice**.

Those inferences are labelled and reversible, but they are not the spec. When the real handoff
arrives it goes here, and every inference gets checked against it — see
[`RECONCILIATION.md`](RECONCILIATION.md) for the exact inventory.

## Expected documents

| # | Document | What it settles |
|---|---|---|
| 01 | PRODUCT_AND_SCREENS.md | What the app is, who uses it, the screens |
| 02 | *not provided — the numbering has a gap between 01 and 03* | |
| 03 | DATABASE_AND_AUTHORIZATION.md | Tables, columns, and who may read or write what |
| 04 | API_AND_INTEGRATION_CONTRACTS.md | External services and the contracts with them |
| 05 | LOCATION_NOTIFICATIONS_AND_OFFLINE.md | Geolocation, push, and offline behaviour |
| 06 | SECURITY_PRIVACY_AND_OPERATIONS.md | Threat model, PII handling, incident response |
| 07 | TESTING_AND_ACCEPTANCE.md | What "done" means, measurable |
| 08 | DELIVERY_PLAN_AND_GIT_WORKFLOW.md | Branching, review, release process |
| 09 | SETUP_DEPLOYMENT_AND_SECRETS.md | Environments, keys, deployment |
| 10 | DECISIONS_AND_OPEN_GATES.md | Decisions already made, and what is still open |
| 11 | IMPLEMENTATION_BACKLOG.md | The ordered work list |

**Please check whether `02` exists.** Its absence means something between "the product" and "the
database" is missing, and that gap is exactly where an inferred schema does the most damage.

## How to get them here

The toolchain that develops this repository cannot reach arbitrary hosts, so the documents have to
be provided one of these ways:

1. **Attach them to the conversation again.** This is the intended path. On 2026-10-14 all eleven
   filenames were listed as attached, but nothing arrived in the sandbox — `find / -name
   '*PRODUCT_AND_SCREENS*'` returned nothing, and the files exist in no branch of
   `testlearn08-cpu/FoodCircle` nor in any other repository on the account. If a re-attach also
   fails, fall back to option 2 or 3.
2. **Paste them into the conversation.** Long is fine. `01` and `03` first, if pasting all of them
   is tedious: those two decide the data model and the screens, and everything else can follow.
3. **Commit them.** Push them to a branch, or add them under this directory in a pull request. If
   they contain anything sensitive, put them in a **private** repository and paste the relevant
   parts instead — see the warning below.

## Warning: do not commit secrets here

`09_SETUP_DEPLOYMENT_AND_SECRETS.md` is likely to quote real values. The repository is **public**,
and `tool/check_no_secrets.py` fails CI if a `service_role` key, a `sb_secret_…` key, a personal
access token or a private key appears in a tracked file. Redact before committing.
