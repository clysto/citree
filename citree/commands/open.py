import platform
import subprocess
from pathlib import Path

import click

from citree.utils import require_repo


@click.command()
@click.argument("entry_id")
@require_repo
def cli(entry_id, base: Path):
    """Open the earliest-attached PDF for an entry."""

    attach_dir = base / "attachments" / entry_id
    if not attach_dir.exists() or not attach_dir.is_dir():
        raise click.ClickException(f"No attachment directory found for entry '{entry_id}'")

    pdfs = list(attach_dir.glob("*.pdf"))
    if not pdfs:
        raise click.ClickException("No PDF attachments found.")

    # Sort by creation time (fallback to modification time if necessary)
    pdfs.sort(key=lambda p: p.stat().st_ctime)

    pdf_to_open = pdfs[0]

    if platform.system() == "Darwin":
        subprocess.run(["open", str(pdf_to_open)])
    elif platform.system() == "Windows":
        subprocess.run(["start", str(pdf_to_open)], shell=True)
    else:
        subprocess.run(["xdg-open", str(pdf_to_open)])
