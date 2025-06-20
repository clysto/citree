import click
import json

import rich.box
from citree.utils import require_repo
from pathlib import Path
import rich
from rich.table import Table
from rich.console import Console


@click.command(name="list")
@require_repo
def cli(base: Path):
    """List all citation entries in the repository"""
    entries_dir = base / "entries"
    if not entries_dir.exists():
        click.echo("No entries directory found.")
        return

    console = Console(highlight=False)
    table = Table(box=rich.box.SIMPLE, width=80)

    table.add_column("ID", style="cyan", no_wrap=True)
    table.add_column("Title", style="white")
    table.add_column("Author", style="magenta")
    table.add_column("Date", style="green")

    found = False
    for entry_file in sorted(entries_dir.glob("*.json")):
        with entry_file.open("r", encoding="utf-8") as f:
            try:
                data = json.load(f)
                title = data.get("title", "<no title>")
                creators = data.get("creators", [])
                if creators:
                    first_creator = creators[0]
                    if "name" in first_creator:
                        name = first_creator["name"]
                    else:
                        name = f"{first_creator.get('lastName', '')}, {first_creator.get('firstName', '')}".strip(", ")
                else:
                    name = ""
                date = data.get("date", "")
                table.add_row(entry_file.stem, title, name, date)
                found = True
            except Exception as e:
                table.add_row(entry_file.stem, f"[red]Failed to parse: {e}[/red]", "", "")
                found = True

    if found:
        console.print(table)
    else:
        click.echo("No entries found.")
