#!/usr/bin/env python3
import os
import signal
import time

import requests


ORG = "https://dev.azure.com/hpc-platform-team"
PROJECT = "hpc-image-val"
API_VERSION = "7.1"
active_run_id = None
session = requests.Session()


def required_env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"{name} is required")
    return value


def build_api_url(run_id):
    return f"{ORG}/{PROJECT}/_apis/build/builds/{run_id}?api-version={API_VERSION}"


def run_web_url(run):
    return run.get("_links", {}).get("web", {}).get("href") or (
        f"{ORG}/{PROJECT}/_build/results?buildId={run['id']}&view=results"
    )


def request(method, url, **kwargs):
    response = session.request(method, url, timeout=60, **kwargs)
    response.raise_for_status()
    return response


def cancel_scanner(signum, _frame):
    if active_run_id is not None:
        try:
            request("PATCH", build_api_url(active_run_id), json={"status": "cancelling"})
            print(f"Requested cancellation of scanner run {active_run_id}.", flush=True)
        except requests.RequestException as error:
            print(f"Could not cancel scanner run {active_run_id}: {error}", flush=True)
    raise SystemExit(128 + signum)


def queue_scanner(pipeline_id, branch, pr_number):
    ref_name = branch if branch.startswith("refs/") else f"refs/heads/{branch}"
    body = {
        "resources": {"repositories": {"self": {"refName": ref_name}}},
        "templateParameters": {
            "pr_number": pr_number,
            "trigger_orchestrator_pipeline": "true",
            "wait_for_orchestrator_pipeline": "true",
            "update_kusto": "false",
            "service_connection": "HPCScrub1_ServiceConn",
            "use_same_branch_for_orchestrator_and_build_pipeline": "true",
        },
    }
    url = f"{ORG}/{PROJECT}/_apis/pipelines/{pipeline_id}/runs?api-version={API_VERSION}"
    return request("POST", url, json=body).json()


def get_scanner(run_id):
    return request("GET", build_api_url(run_id)).json()


def main():
    global active_run_id

    token = required_env("SYSTEM_ACCESSTOKEN")
    session.headers.update(
        {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    )
    signal.signal(signal.SIGINT, cancel_scanner)
    signal.signal(signal.SIGTERM, cancel_scanner)

    existing_run_id = os.environ.get("EXISTING_SCANNER_RUN_ID", "").strip()
    poll_interval = int(required_env("POLL_INTERVAL_SECONDS"))
    if poll_interval <= 0:
        raise SystemExit("POLL_INTERVAL_SECONDS must be greater than zero")

    if existing_run_id:
        active_run_id = int(existing_run_id)
        run = get_scanner(active_run_id)
    else:
        pr_number = required_env("PR_NUM")
        pipeline_id = int(required_env("SCANNER_PIPELINE_ID"))
        branch = required_env("SCANNER_BRANCH")
        run = queue_scanner(pipeline_id, branch, pr_number)
        active_run_id = int(run["id"])

    print(f"Scanner run: {run_web_url(run)}", flush=True)
    while True:
        run = get_scanner(active_run_id)
        status = run.get("status")
        result = run.get("result")
        print(
            f"Scanner run {active_run_id}: status={status} result={result} "
            f"url={run_web_url(run)}",
            flush=True,
        )
        if status == "completed":
            if result != "succeeded":
                raise SystemExit(
                    f"Scanner run {active_run_id} completed with result '{result}'."
                )
            active_run_id = None
            return
        time.sleep(poll_interval)


if __name__ == "__main__":
    main()