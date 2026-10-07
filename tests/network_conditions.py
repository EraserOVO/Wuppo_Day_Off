"""Run real ENet processes through a UDP delay/jitter/loss proxy or recovery cases."""
import argparse
import heapq
import os
import random
import selectors
import shutil
import socket
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def resolve_engine():
    configured = os.environ.get("GODOT", "").strip()
    candidates = [configured] if configured else [shutil.which(name) for name in ("godot", "godot4", "godot-console")]
    for candidate in candidates:
        if not candidate:
            continue
        engine = Path(candidate)
        if engine.is_file():
            return engine.resolve()
        located = shutil.which(candidate)
        if located:
            return Path(located).resolve()
    raise SystemExit("Godot was not found. Add it to PATH or set the GODOT environment variable.")


def run(case):
    engine = resolve_engine()
    rng = random.Random(731)
    processes = []
    logs = []
    selector = selectors.DefaultSelector()
    pending = []
    packet_serial = 0
    remote_client = None
    host_killed = False
    proxy = case == "latency"
    sockets = []
    if proxy:
        incoming = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        incoming.bind(("127.0.0.2", 7000))
        outgoing = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        outgoing.bind(("127.0.0.1", 0))
        sockets = [incoming, outgoing]
        for sock in sockets:
            sock.setblocking(False)
            selector.register(sock, selectors.EVENT_READ)
    directory = ROOT / ".godot" / "network_checks" / case
    directory.mkdir(parents=True, exist_ok=True)
    script = "network_mechanics_smoke.gd" if proxy else "network_recovery_smoke.gd"
    roles = ["host", "client"] + (["client"] if case in ("handover", "crash") else [])
    try:
        for index, role in enumerate(roles):
            args = [str(engine), "--headless", "--path", str(ROOT), "--script", "tests/" + script, "--audio-driver", "Dummy", "--", role]
            if proxy and role == "client": args += ["address=127.0.0.2"]
            if case in ("handover", "crash"): args += ["migration"]
            if case == "crash": args += ["crash"]
            output = open(directory / f"{index}_{role}.log", "w", encoding="utf-8")
            logs.append(output)
            processes.append(subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT))
        deadline = time.monotonic() + 45
        while any(process.poll() is None for process in processes) and time.monotonic() < deadline:
            if case == "crash" and not host_killed and "scored state replicated; crash" in (directory / "0_host.log").read_text(encoding="utf-8"):
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(processes[0].pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                else:
                    processes[0].kill()
                host_killed = True
            if not proxy: time.sleep(0.03)
            for key, _ in (selector.select(0.003) if proxy else []):
                sock = key.fileobj
                try:
                    packet, address = sock.recvfrom(65536)
                except (ConnectionResetError, BlockingIOError):
                    continue
                if rng.random() < 0.05: continue
                if sock is incoming:
                    remote_client = address
                    destination, sending = ("127.0.0.1", 7000), outgoing
                else:
                    if remote_client is None: continue
                    destination, sending = remote_client, incoming
                packet_serial += 1
                heapq.heappush(pending, (time.monotonic() + rng.uniform(0.06, 0.10), packet_serial, sending, destination, packet))
            while pending and pending[0][0] <= time.monotonic():
                _, _, sending, destination, packet = heapq.heappop(pending)
                sending.sendto(packet, destination)
        codes = [process.poll() for process in processes]
        checked = codes[1:] if host_killed else codes
        if any(code != 0 for code in checked): raise RuntimeError(f"{case}: process exit codes {codes}")
        for output in logs: output.flush()
        for path in directory.glob("*.log"):
            if "ERROR:" in path.read_text(encoding="utf-8"):
                raise RuntimeError(f"{case}: unexpected error in {path.name}")
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        for log in logs: log.close()
        for sock in sockets: sock.close()
        selector.close()
        for path in sorted(directory.glob("*.log")):
            content = path.read_text(encoding="utf-8")
            print(path.name + "\n" + (content[:7000] if len(content) > 7000 else content))
    print(f"NETWORK CONDITIONS: {case} passed" + (" (160 ms nominal RTT, 40 ms jitter range, 5% packet loss)" if proxy else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("case", choices=["latency", "reconnect", "handover", "crash"])
    run(parser.parse_args().case)
