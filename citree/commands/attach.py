import click
import shutil
from pathlib import Path
from citree.utils import require_repo


@click.command()
@click.argument("entry_id")
@click.argument("file", type=click.Path(exists=True, dir_okay=False, readable=True, resolve_path=True))
@require_repo
def cli(entry_id, file, base: Path):
    """Attach a file to a citation entry by ID"""

    attachments_dir = base / "attachments"
    attachments_dir.mkdir(exist_ok=True)

    ext = Path(file).suffix.lower()
    if ext not in [".pdf", ".ppt", ".pptx", ".docx"]:
        click.confirm(f"File extension '{ext}' is unusual. Continue?", abort=True)

    entry_dir = attachments_dir / f"{entry_id}"
    entry_dir.mkdir(parents=True, exist_ok=True)

    target_path = entry_dir / Path(file).name

    shutil.copy2(file, target_path)

    click.echo(f"Attached {file} to entry {entry_id} as {target_path.name}")
