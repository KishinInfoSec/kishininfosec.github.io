---
layout: template
title: LimaCharlie detection triage → Slack
kind: n8n
summary: Every 5 minutes, pulls new LimaCharlie detections, adds sensor and process context, flags known false positives and posts a summary to Slack. Optional Claude triage step.
tags: [limacharlie, edr, slack, triage]
tested: n8n 2.43
permalink: /n8n/lc-detection-triage/
---

# LimaCharlie detection triage → Slack

Every 5 minutes this workflow pulls new [LimaCharlie](https://limacharlie.io) detections. For each one it looks up the sensor and the parent process, flags known false positives, and posts a summary to Slack. Each detection is posted once, because n8n's Remove Duplicates node remembers up to 10,000 IDs.

**A human makes the final call.** The workflow only suggests a verdict. It never creates false-positive rules or closes anything. Give its API key no `fp.ctrl` permission.

## Setup

1. Import `workflow.json`.
2. Create the credentials. `credentials.placeholder.json` lists their names and types:
   - **LimaCharlie API key (X-LC-SECRET).** Header Auth, header name `X-LC-SECRET`. Use an org API key that has only `insight.det.get`, `insight.evt.get` and `sensor.get`.
   - **Slack bot token.** Needs a bot token with `chat:write`. Invite the bot to the channel.
   - **Anthropic API key (x-api-key).** Only needed for the optional AI step.
3. In the **Config** node, set `oid` (your LimaCharlie organisation ID) and `slack_channel`. The default channel is `#lc-alerts`.
4. Activate the workflow.

## Optional AI triage

The *AI triage (optional)* node calls the Claude Messages API and returns structured JSON. It ships disabled, and a disabled node passes items through unchanged. To turn it on, set the Anthropic credential and enable the node. The prompt and output schema are in the `ai_request` field of the *Build triage context* Code node.

You can swap in n8n's AI Agent node at the same position instead. *Compose message* reads these JSON fields: `suggested_verdict`, `confidence`, `summary`, `reasoning` and `next_steps`.

## Known false positives

Edit `KNOWN_FPS` at the top of *Build triage context*. Each entry matches a regex against the detection name and another against the parent process path. The included example covers ufw rebuilding its iptables chains, which trips `00326-NIX-Host_Based_Firewall_Disabled`.

## Notes

- LimaCharlie needs the API key in the `X-LC-SECRET` header. `jwt.limacharlie.io` rejects secrets passed as URL parameters.
- Each run looks back 15 minutes (`lookback_minutes` in Config). This overlaps the 5-minute schedule, and the dedupe step absorbs the overlap. Each run fetches at most 1000 detections.
