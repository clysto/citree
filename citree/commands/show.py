import click
from pathlib import Path
from citree.utils import require_repo
from rich.console import Console
import json

from citree.utils.schema import ZOTERO_SCHEMA


@click.command()
@click.argument("entry_id")
@require_repo
def cli(entry_id, base: Path):
    """Show the full metadata of a citation entry."""

    entry_file = base / "entries" / f"{entry_id}.json"
    if not entry_file.exists():
        raise click.ClickException(f"No such entry: {entry_id}")

    with entry_file.open("rb") as f:
        data = json.load(f)

    console = Console(highlight=False)
    console.print(f"[bold cyan]ID:[/bold cyan] {entry_id}")
    console.print(f"[bold cyan]Title:[/bold cyan] {data.get('title', '<no title>')}")

    item_type = data.get("itemType")
    matched_schema = next((s for s in ZOTERO_SCHEMA["itemTypes"] if s["itemType"] == item_type), None)

    if not matched_schema:
        console.print(f"[red]Unknown item type:[/red] {item_type}")
        return

    fields = matched_schema.get("fields", [])
    shown = {"id", "title", "itemType"}

    for field in fields:
        key = field["field"]
        if key in shown or key not in data or not data[key]:
            continue
        value = data[key]
        if key == "creators" and isinstance(value, list):
            names = []
            for a in value:
                if isinstance(a, dict):
                    name = a.get("name") or f"{a.get('lastName', '')}, {a.get('firstName', '')}".strip(", ")
                    names.append(name)
                else:
                    names.append(str(a))
            console.print(f"[bold cyan]Authors:[/bold cyan] {', '.join(names)}")
        elif key == "DOI":
            console.print(f"[bold cyan]DOI:[/bold cyan] https://doi.org/{value}")
        else:
            label = ZOTERO_SCHEMA["locales"]["en-US"]["fields"][key]
            console.print(f"[bold cyan]{label}:[/bold cyan] {value}")
