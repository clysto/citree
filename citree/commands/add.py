import click
import requests
from pathlib import Path
import tomli_w
from citree.utils import generate_entry_id, require_repo


def fetch_csl_from_doi(doi: str) -> dict:
    url = f"https://doi.org/{doi}"
    headers = {"Accept": "application/vnd.citationstyles.csl+json"}
    response = requests.get(url, headers=headers)
    if not response.ok:
        raise click.ClickException(f"DOI lookup failed: {response.status_code} {response.text}")
    return response.json()


@click.command()
@click.argument("doi")
@require_repo
def cli(doi, base: Path):
    """Add a new citation entry via DOI"""
    try:
        data = fetch_csl_from_doi(doi)
    except Exception as e:
        click.echo(f"Error: {e}")
        return

    entry_id = generate_entry_id()
    entries_dir = base / "entries"
    entries_dir.mkdir(exist_ok=True)
    entry_path = entries_dir / f"{entry_id}.toml"

    with entry_path.open("wb") as f:
        tomli_w.dump(data, f)

    click.echo(f"Entry saved to: {entry_path}")
