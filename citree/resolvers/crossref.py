import re
import urllib.parse

import requests

from citree.utils.zotero import empty_zotero_item

from .base import BaseResolver


class CrossRefResolver(BaseResolver):
    """
    Resolver for CrossRef DOIs.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    @classmethod
    def can_resolve(cls, query: str) -> bool:
        return True

    def resolve(self, doi: str) -> dict:
        url = f"https://api.crossref.org/works/{doi}"
        response = requests.get(url)
        if not response.ok:
            raise Exception(f"CrossRef lookup failed: {response.status_code} {response.text}")
        return process_crossref(response.json()["message"])


def fix_author_capitalization(string):
    if isinstance(string, str) and string.upper() == string:
        string = string.lower()
        string = " ".join(word.capitalize() for word in string.split())
    return string


def parse_creators(result, item, type_override_map):
    types = ["author", "editor", "chair", "translator"]

    for type_ in types:
        if type_ in result:
            creator_type = type_override_map.get(type_) if type_override_map and type_ in type_override_map else (type_ if type_ in ["author", "editor", "translator"] else "contributor")

            if not creator_type:
                continue

            for creator in result[type_]:
                new_creator = {}
                new_creator["creatorType"] = creator_type

                if "name" in creator:
                    new_creator["fieldMode"] = 1
                    new_creator["lastName"] = creator["name"]
                else:
                    new_creator["firstName"] = fix_author_capitalization(creator["given"])
                    new_creator["lastName"] = fix_author_capitalization(creator["family"])
                    if not new_creator["firstName"]:
                        new_creator["fieldMode"] = 1

                item["creators"].append(new_creator)


def decode_entities(n):
    escaped = {"&amp;": "&", "&quot;": '"', "&lt;": "<", "&gt;": ">"}
    return re.sub(r"(&quot;|&lt;|&gt;|&amp;)", lambda match: escaped[match.group(0)], n.replace("\n", ""))


def parse_date(date_obj):
    if date_obj and "date-parts" in date_obj and date_obj["date-parts"]:
        year, month, day = date_obj["date-parts"][0]
        if year:
            if month:
                if day:
                    return f"{year}-{str(month).zfill(2)}-{str(day).zfill(2)}"
                else:
                    return f"{str(month).zfill(2)}/{year}"
            else:
                return str(year)
    return None


def process_crossref(result: dict) -> dict:
    """Process a CrossRef result into a Zotero item."""
    creator_type_override_map = {}
    item = None
    if result["type"] in ["journal", "journal-article", "journal-volume", "journal-issue"]:
        item = empty_zotero_item("journalArticle")
    elif result["type"] in ["report", "report-series", "report-component"]:
        item = empty_zotero_item("report")
    elif result["type"] in ["book", "book-series", "book-set", "book-track", "monograph", "reference-book", "edited-book"]:
        item = empty_zotero_item("book")
    elif result["type"] in ["book-chapter", "book-part", "book-section", "reference-entry"]:
        item = empty_zotero_item("bookSection")
        creator_type_override_map = {"author": "bookAuthor"}
    elif result["type"] == "other" and "ISBN" in result and "container-title" in result:
        item = empty_zotero_item("bookSection")
        if len(result["container-title"]) >= 2:
            item["seriesTitle"] = result["container-title"][0]
            item["bookTitle"] = result["container-title"][1]
        else:
            item["bookTitle"] = result["container-title"][0]
        creator_type_override_map = {"author": "bookAuthor"}
    elif result["type"] == "standard":
        item = empty_zotero_item("standard")
    elif result["type"] in ["dataset", "database"]:
        item = empty_zotero_item("dataset")
    elif result["type"] in ["proceedings", "proceedings-article", "proceedings-series"]:
        item = empty_zotero_item("conferencePaper")
    elif result["type"] == "dissertation":
        item = empty_zotero_item("thesis")
        item["date"] = parse_date(result["approved"])
        item["thesisType"] = result.get("degree", [{}])[0].get("degree", "").replace("(", "").replace(")", "")
    elif result["type"] == "posted-content":
        if result.get("subtype") == "preprint":
            item = empty_zotero_item("preprint")
            item["repository"] = result["group-title"]
        else:
            item = empty_zotero_item("blogPost")
            if "institution" in result and result["institution"]:
                item["blogTitle"] = result["institution"][0].get("name", "")
    elif result["type"] == "peer-review":
        item = empty_zotero_item("manuscript")
        item["type"] = "peer review"
        if "author" not in result:
            item["creators"].append({"lastName": "Anonymous Reviewer", "fieldMode": 1, "creatorType": "author"})
        if "relation" in result and "is-review-of" in result["relation"] and result["relation"]["is-review-of"]:
            identifier = None
            review_of = result["relation"]["is-review-of"][0]
            type_ = review_of["id-type"]
            id_ = review_of["id"]
            if type_ == "doi":
                identifier = f'<a href="https://doi.org/{id_}">https://doi.org/{id_}</a>'
            elif type_ == "url":
                identifier = f'<a href="{id_}">{id_}</a>'
            else:
                identifier = id_
            item["notes"].append(f"Review of {identifier}")
    else:
        item = empty_zotero_item("document")

    parse_creators(result, item, creator_type_override_map)

    if "description" in result:
        item["notes"].append(result["description"])

    item["abstractNote"] = result.get("abstract", None)
    item["pages"] = result.get("page")
    item["ISBN"] = result.get("ISBN") and ", ".join(result["ISBN"])
    item["ISSN"] = result.get("ISSN") and ", ".join(result["ISSN"])
    item["issue"] = result.get("issue")
    item["volume"] = result.get("volume")
    item["language"] = result.get("language")
    item["edition"] = result.get("edition-number")
    item["university"] = item["institution"] = item["publisher"] = result.get("publisher")

    if result.get("container-title") and result["container-title"][0]:
        if "journalArticle" in [item.get("itemType")]:
            item["publicationTitle"] = result["container-title"][0]
        elif "conferencePaper" in [item.get("itemType")]:
            item["proceedingsTitle"] = result["container-title"][0]
        elif "book" in [item.get("itemType")]:
            item["series"] = result["container-title"][0]
        elif "bookSection" in [item.get("itemType")]:
            item["bookTitle"] = result["container-title"][0]
        else:
            item["seriesTitle"] = result["container-title"][0]

    item["conferenceName"] = result.get("event") and result["event"].get("name")

    if result.get("short-container-title") and result["short-container-title"][0] != result["container-title"][0]:
        item["journalAbbreviation"] = result["short-container-title"][0]

    if result.get("event") and result["event"].get("location"):
        item["place"] = result["event"]["location"]
    elif result.get("institution") and result["institution"][0] and result["institution"][0].get("place"):
        item["place"] = ", ".join(result["institution"][0]["place"])
    else:
        item["place"] = result.get("publisher-location")

    item["institution"] = item["university"] = result.get("institution") and result["institution"][0] and result["institution"][0].get("name")

    if parse_date(result.get("published-print")):
        item["date"] = parse_date(result["published-print"])
    elif parse_date(result.get("issued")):
        item["date"] = parse_date(result["issued"])

    item["DOI"] = result.get("DOI")

    item["url"] = result.get("resource") and result["resource"].get("primary") and result["resource"]["primary"].get("URL")

    item["rights"] = result.get("license") and result["license"][0] and result["license"][0].get("URL")

    if result.get("title") and result["title"][0]:
        item["title"] = result["title"][0]
        if result.get("subtitle") and result["subtitle"][0]:
            if item["title"].lower().find(result["subtitle"][0].lower()) < 0:
                if item["title"][-1] != ":":
                    item["title"] += ":"
                item["title"] += " " + result["subtitle"][0]
        item["title"] = item["title"]

    if "title" not in item:
        item["title"] = "[No title found]"

    # Check if there are potential issues with character encoding and try to fix them.
    # E.g., in 10.1057/9780230391116.0016, the en dash in the title is displayed as â<80><93>,
    # which is what you get if you decode a UTF-8 en dash (<E2><80><93>) as Latin-1 and then serve
    # as UTF-8 (<C3><A2> <C2><80> <C2><93>)
    for field in item:
        if not isinstance(item[field], str):
            continue
        # Check for control characters that should never be in strings from Crossref
        if re.search(r"[\u007F-\u009F]", item[field]):
            # <E2><80><93> -> %E2%80%93 -> en dash
            try:
                item[field] = urllib.parse.unquote(item[field].encode("latin1").decode("utf-8"))
            except Exception:
                item[field] = re.sub(r"[\u0000-\u001F\u007F-\u009F]", "", item[field])
        item[field] = decode_entities(item[field])

    item["libraryCatalog"] = "Crossref"

    return item
