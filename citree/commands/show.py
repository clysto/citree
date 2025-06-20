import json
from pathlib import Path

import click
from rich.console import Console
from rich.table import Table

from citree.utils import require_repo
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
    table = Table(show_header=False, box=None, padding=(0, 1), width=80)
    table.add_row("[cyan]ID[/cyan]", entry_id)
    table.add_row("[cyan]Title[/cyan]", data.get("title", "<no title>"))

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
            value_str = ", ".join(names)
            label = "Authors"
        elif key == "abstractNote" or key == "notes":
            continue
        else:
            label = ZOTERO_SCHEMA["locales"]["en-US"]["fields"].get(key, key)
            value_str = str(value)
        table.add_row(f"[cyan]{label}[/cyan]", value_str)

    console.print(table)
