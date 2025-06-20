from .schema import ZOTERO_SCHEMA


def empty_zotero_item(item_type) -> dict:
    """
    Returns an empty Zotero item.
    """

    matched_schemas = list(filter(lambda x: x["itemType"] == item_type, ZOTERO_SCHEMA["itemTypes"]))
    if len(matched_schemas) == 0:
        raise ValueError(f"Unknown item type: {item_type}")

    schema = matched_schemas[0]

    item = {
        "key": "",
        "itemType": item_type,
        "creators": [],
        "notes": [],
    }

    for field in schema["fields"]:
        item[field["field"]] = None

    return item
