import click
from citree.commands import init, add, attach, list


@click.group()
def cli():
    pass


cli.add_command(init.cli, name="init")
cli.add_command(add.cli, name="add")
cli.add_command(attach.cli, name="attach")
cli.add_command(list.cli, name="list")
