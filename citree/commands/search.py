import subprocess
import click
from pathlib import Path
from citree.utils import require_repo
from rich.console import Console
import json
from collections import defaultdict


@click.command()
@click.argument("keyword", required=True)
@require_repo
def cli(keyword, base: Path):
    """Search attachments for a given keyword using rga."""

    attachments_dir = base / "attachments"
    if not attachments_dir.exists():
        raise click.ClickException("No attachments directory found.")

    try:
        result = subprocess.run(
            ["rga", "--json", keyword, str(attachments_dir)],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        raise click.ClickException(f"rga failed: {e.stderr.strip()}")

    output = result.stdout.strip()
    if not output:
        click.echo("No results found.")
        return

    match_counts = defaultdict(int)
    for line in output.splitlines():
        try:
            obj = json.loads(line)
            if obj.get("type") == "match":
                path = obj["data"]["path"]["text"]
                match_counts[path] += 1
        except json.JSONDecodeError:
            continue

    if not match_counts:
        click.echo("No readable results found.")
        return

    console = Console()
    for path, count in sorted(match_counts.items()):
        console.print(f"[cyan]{path}[/cyan]: [green]{count}[/green] match(es)")
