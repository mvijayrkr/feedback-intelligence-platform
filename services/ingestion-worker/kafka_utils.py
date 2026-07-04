import os, socket, subprocess
from pathlib import Path

TF_DIR = "infra/terraform/envs/local-floci"

def terraform_output(name: str) -> str:
    try:
        return subprocess.check_output(
            ["terraform", f"-chdir={TF_DIR}", "output", "-raw", name],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""

def get_bootstrap_servers() -> str:
    return os.getenv("KAFKA_BOOTSTRAP_SERVERS") or terraform_output("kafka_bootstrap_brokers") or "localhost:9092"

def is_internal_docker_address(bootstrap: str) -> bool:
    host = bootstrap.split(",")[0].split(":")[0].strip()
    return host.startswith(("172.", "10.", "192.168."))

def can_connect(bootstrap: str, timeout: float = 3.0) -> bool:
    host, _, port_s = bootstrap.split(",")[0].partition(":")
    try:
        with socket.create_connection((host, int(port_s)), timeout=timeout):
            return True
    except Exception:
        return False

def write_bronze_local(event_json: str, event_id: str) -> None:
    out_dir = Path("data/bronze/local")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{event_id}.json").write_text(event_json, encoding="utf-8")