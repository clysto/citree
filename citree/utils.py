import nanoid
from pathlib import Path
import click
import functools


def generate_entry_id() -> str:
    """Generate a unique entry ID using nanoid."""
    return nanoid.generate(alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", size=8)


def is_citree_repo(path: Path) -> bool:
    """Check whether the given path is a citree repository."""
    return (path / ".citree").is_file()


def require_repo(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        cwd = Path.cwd()
        if not is_citree_repo(cwd):
            raise click.ClickException(f"Not a citree repository (missing .citree in {cwd})")
        kwargs["base"] = cwd
        return f(*args, **kwargs)

    return wrapper
