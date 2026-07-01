#!/usr/bin/env python3
"""
incident_copilot.py — an AI-assisted incident summariser.

When something looks wrong, this script pulls recent logs from the
app running in Kubernetes, sends them to a local LLM (via Ollama),
and prints a plain-English explanation of what's likely happening.

This is a lightweight "AIOps" copilot: it turns raw logs into a
first-draft diagnosis so an on-call engineer starts with an
explanation instead of a wall of text.

Usage:
    python3 incident_copilot.py
    python3 incident_copilot.py --deployment app --lines 100
"""

import argparse
import subprocess
import sys
import json
import urllib.request

# --- Config ----------------------------------------------------
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "llama3.2"


def get_logs(deployment: str, lines: int) -> str:
    """Fetch the last N log lines from a Kubernetes deployment."""
    try:
        result = subprocess.run(
            ["kubectl", "logs", f"deployment/{deployment}", "--tail", str(lines)],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return f"ERROR fetching logs: {result.stderr.strip()}"
        return result.stdout.strip() or "(no logs returned)"
    except FileNotFoundError:
        sys.exit("kubectl not found — is it installed and on your PATH?")
    except subprocess.TimeoutExpired:
        return "ERROR: kubectl logs timed out (cluster unreachable?)"


def build_prompt(logs: str, deployment: str) -> str:
    """Wrap the logs in an SRE-style instruction for the model."""
    return f"""You are an experienced Site Reliability Engineer helping during an incident.

Below are the most recent logs from a Kubernetes service called "{deployment}"
(a URL shortener API built with FastAPI, backed by PostgreSQL and Redis).

Analyse the logs and respond with:
1. A one-sentence summary of the current state (healthy or not).
2. Any errors or warning signs you notice, in plain English.
3. The most likely root cause, if anything looks wrong.
4. A concrete next step to investigate or fix.

Be concise and practical. If the logs look healthy, say so clearly.

--- LOGS ---
{logs}
--- END LOGS ---
"""


def ask_ollama(prompt: str) -> str:
    """Send the prompt to the local Ollama model and return its answer."""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
    }).encode("utf-8")

    req = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("response", "(no response from model)").strip()
    except urllib.error.URLError as e:
        sys.exit(f"Could not reach Ollama at {OLLAMA_URL} — is it running? ({e})")


def main() -> None:
    parser = argparse.ArgumentParser(description="AI incident copilot")
    parser.add_argument("--deployment", default="app", help="k8s deployment to inspect")
    parser.add_argument("--lines", type=int, default=100, help="how many log lines to read")
    args = parser.parse_args()

    print(f"==> Fetching last {args.lines} log lines from deployment/{args.deployment}...")
    logs = get_logs(args.deployment, args.lines)

    print("==> Asking the AI copilot to analyse the logs...\n")
    prompt = build_prompt(logs, args.deployment)
    answer = ask_ollama(prompt)

    print("=" * 60)
    print("  AI INCIDENT COPILOT — DIAGNOSIS")
    print("=" * 60)
    print(answer)
    print("=" * 60)


if __name__ == "__main__":
    main()
