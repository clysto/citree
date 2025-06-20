import json
from pathlib import Path

import click

from citree.resolvers import CrossRefResolver
from citree.utils import generate_entry_id, require_repo


@click.command()
@click.argument("doi")
@require_repo
def cli(doi, base: Path):
    """Add a new citation entry via DOI"""
    try:
        resolver = CrossRefResolver()
        item = resolver.resolve(doi)
    except Exception as e:
        click.echo(f"Error: {e}")
        return

    entry_id = generate_entry_id()
    item["key"] = entry_id
    entries_dir = base / "entries"
    entries_dir.mkdir(exist_ok=True)
    entry_path = entries_dir / f"{entry_id}.json"

    with entry_path.open("w") as f:
        json.dump(item, f, indent=2)

    click.echo(f"Entry saved to: {entry_path}")
