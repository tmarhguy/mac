#!/usr/bin/env python3
"""Open a hardened GDS in KLayout, or export a PNG preview if the GUI app is missing."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GDS = ROOT / "runs/mac/final/gds/mac_core.gds"
DEFAULT_PNG = ROOT / "runs/mac/mac_core_preview.png"


def export_png(gds: Path, png: Path, width: int = 1600, height: int = 1600) -> None:
    import klayout.lay as lay

    png.parent.mkdir(parents=True, exist_ok=True)
    lv = lay.LayoutView()
    lv.load_layout(str(gds))
    lv.max_hier()
    lv.save_image(str(png), width, height)
    print(f"PNG preview: {png}")


def find_klayout_app() -> Path | None:
    candidates = [
        Path("/Applications/KLayout.app"),
        Path.home() / "Applications/KLayout.app",
    ]
    for app in candidates:
        if app.is_dir():
            return app
    return None


def open_in_klayout(gds: Path) -> bool:
    """Try native KLayout GUI (macOS app bundle or klayout on PATH)."""
    gds = gds.resolve()
    if not gds.is_file():
        print(f"GDS not found: {gds}", file=sys.stderr)
        return False

    app = find_klayout_app()
    if app is not None:
        mac_bin = app / "Contents/MacOS/klayout"
        if mac_bin.is_file():
            subprocess.Popen([str(mac_bin), str(gds)])
            print(f"Opened in KLayout: {gds}")
            return True
        subprocess.Popen(["open", "-a", "KLayout", str(gds)])
        print(f"Opened in KLayout: {gds}")
        return True

    klayout_bin = shutil.which("klayout")
    if klayout_bin:
        subprocess.Popen([klayout_bin, str(gds)])
        print(f"Opened in KLayout: {gds}")
        return True

    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="View hardened GDS in KLayout or export PNG")
    parser.add_argument("gds", nargs="?", default=str(DEFAULT_GDS), help="Path to GDS file")
    parser.add_argument(
        "--png",
        default=str(DEFAULT_PNG),
        help="PNG fallback path when KLayout GUI is not installed",
    )
    parser.add_argument("--png-only", action="store_true", help="Only export PNG, do not launch GUI")
    args = parser.parse_args()

    gds = Path(args.gds)
    png = Path(args.png)

    if not gds.is_file():
        print(f"Missing GDS: {gds}\nRun: make librelane", file=sys.stderr)
        return 1

    if args.png_only:
        export_png(gds, png)
        return 0

    if open_in_klayout(gds):
        return 0

    print("KLayout GUI not found — exporting PNG preview instead.")
    print("Install KLayout: https://www.klayout.de/build.html")
    export_png(gds, png)

    if sys.platform == "darwin":
        subprocess.run(["open", str(png)], check=False)
    else:
        print(f"Open manually: {png}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
