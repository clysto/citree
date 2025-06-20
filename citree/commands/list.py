import click
import tomllib
from citree.utils import require_repo
from pathlib import Path
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

    console = Console()
    table = Table()

    table.add_column("ID", style="cyan", no_wrap=True)
    table.add_column("Title", style="white")
    table.add_column("Author", style="magenta")
    table.add_column("Year", style="green")

    found = False
    for entry_file in sorted(entries_dir.glob("*.toml")):
        with entry_file.open("rb") as f:
            try:
                data = tomllib.load(f)
                title = data.get("title", "<no title>")
                author = data.get("author", [{}])[0]
                if isinstance(author, dict):
                    name = author.get("literal") or f"{author.get('family', '')}, {author.get('given', '')}"
                else:
                    name = author
                year = str(data.get("issued", {}).get("date-parts", [[None]])[0][0] or "")
                table.add_row(entry_file.stem, title, name, year)
                found = True
            except Exception as e:
                table.add_row(entry_file.stem, f"[red]Failed to parse: {e}[/red]", "", "")
                found = True

    if found:
        console.print(table)
    else:
        click.echo("No entries found.")
