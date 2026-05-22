"""`cmd_build` - AOT-compile every scenario + micro source to `BUILD_DIR`.

Parallelises across workers - safe because compilation does no measurement,
contention only affects wall-clock. `ThreadPoolExecutor` is enough because
each worker is just waiting on `subprocess.run` (releases the GIL).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import os
import subprocess
import sys
from pathlib import Path

from bicc_bench.config import BUILD_DIR, PROJECT_ROOT
from bicc_bench.data.utils.io import discover_sources


def cmd_build(args: argparse.Namespace) -> int:
    """AOT-compile every .dart file under scenarios/ and micro/ to BUILD_DIR.

    Uses `dart compile exe`. Skips files that compile cleanly already unless
    --force is given. AOT compilation is required for deterministic warmup
    characteristics - JIT introduces too much variance.
    """
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    sources = list(discover_sources())
    if not sources:
        print("no scenario or micro sources to build (yet)", file=sys.stderr)
        return 0

    targets: list[tuple[Path, Path]] = []
    for src in sources:
        out = BUILD_DIR / src.stem
        if out.exists() and not args.force:
            print(f"skip   {src.relative_to(PROJECT_ROOT)} (exe up to date; --force to rebuild)")
            continue
        targets.append((src, out))

    if not targets:
        return 0

    cpu = os.cpu_count() or 1
    # Cap at 4 - parallel `dart compile exe` can spike RAM (~1 GB each peak)
    # and we don't want to OOM on 16 GB machines. Override with --workers.
    workers = args.workers if args.workers else min(cpu, 4)
    print(f"building {len(targets)} target(s) with {workers} parallel worker(s)")

    failed: list[Path] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_to_src = {pool.submit(_compile_one, src, out): src for src, out in targets}
        for future in concurrent.futures.as_completed(future_to_src):
            src = future_to_src[future]
            ok = future.result()
            status = "ok  " if ok else "FAIL"
            print(f"{status}  {src.relative_to(PROJECT_ROOT)}")
            if not ok:
                failed.append(src)

    if failed:
        print(f"\n{len(failed)} build(s) failed", file=sys.stderr)
        return 1
    return 0


def _compile_one(src: Path, out: Path) -> bool:
    """Single `dart compile exe` invocation. Suppresses stdout, surfaces stderr on failure."""
    result = subprocess.run(
        ["dart", "compile", "exe", str(src), "-o", str(out)],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(f"\n--- {src.name} stderr ---\n{result.stderr}\n", file=sys.stderr)
        return False
    return True
