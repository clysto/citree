import click
from pathlib import Path


@click.command()
@click.argument("path", default=".")
def cli(path):
    """Initialize a new citation repository at the given path"""
    base = Path(path).resolve()

    config = base / ".citree"
    if config.exists():
        raise click.ClickException(f"The directory '{base}' is already a citree repository.")
    config.touch()

    entries = base / "entries"
    attachments = base / "attachments"

    entries.mkdir(parents=True, exist_ok=True)
    attachments.mkdir(parents=True, exist_ok=True)

    click.echo(f"Initialized citree repository at {base}")
