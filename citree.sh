#!/usr/bin/env bash
# @describe Citree - A simple command-line citation manager (Yachen Mao)
# @meta version 0.1.0
# @meta require-tools jq,pandoc,curl,fzf,rga,gum

set -eu

ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
CITREE_DEFAULT_REPO="${CITREE_DEFAULT_REPO:-}"
CITREE_REPO=""

gennanoid() {
    local id=""
    local len=8
    local alpha_len=${#ALPHABET}

    for ((i = 0; i < len; i++)); do
        rand_num=$(head -c 2 /dev/urandom | od -An -tu2 | tr -d ' ')
        index=$((rand_num % alpha_len))
        id+="${ALPHABET:index:1}"
    done

    echo "$id"
}

genindex() {
    for file in $CITREE_REPO/entries/*.json; do
        if [ -f "$file" ]; then
            local id=$(basename "$file" .json)
            local json=$(<"$file")
            local title=$(echo "$json" | jq -r '.title')
            local authors=$(echo "$json" | jq -r '[.author[] | .given + " " + .family] | join(", ")')
            local issued=$(echo "$json" | jq -r '.issued["date-parts"][0] | join("-")')
            local journal=$(echo "$json" | jq -r '."container-title"')
            local collection=$(echo "$json" | jq -r '."collection-title"')
            echo -e "$id\t$title\t$authors\t$issued\t$journal\t$collection"
        fi
    done >"$CITREE_REPO/.citree/index"
    # clean recent file entries that no longer exist in index
    grep -Ff <(cut -f1 "$CITREE_REPO/.citree/index") "$CITREE_REPO/.citree/recent" >"$CITREE_REPO/.citree/recent.tmp"
    mv "$CITREE_REPO/.citree/recent.tmp" "$CITREE_REPO/.citree/recent"
}

updaterecent() {
    local id="$1"
    local recent_file="$CITREE_REPO/.citree/recent"
    {
        echo "$id"
        grep -vxF "$id" "$recent_file"
    } | head -n 50 >"$recent_file.tmp"
    mv "$recent_file.tmp" "$recent_file"
}

# @cmd Initialize a new citation repository
init() {
    mkdir -p entries attachments .citree
    touch .citree/index
    touch .citree/recent
    echo "citation repository initialized"
}

# @cmd Show details of a citation entry by ID
# @arg id!
show() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist."
        exit 1
    fi
    local json=$(<"$CITREE_REPO/entries/$argc_id.json")
    echo -e "\033[36mID:\033[0m"
    echo -n "  "
    echo -e "\033[1m$argc_id\033[0m"
    echo -e "\033[36mTitle:\033[0m"
    echo -n "  "
    echo -e "\033[1m$(echo "$json" | jq -r .title)\033[0m"
    if echo "$json" | jq -e '.author? // empty' >/dev/null; then
        echo -e "\033[36mAuthors:\033[0m"
        echo "$json" | jq -r '.author[] | select(.given != null and .family != null) | "  " + .given + " " + .family'
    fi
    echo -e "\033[36mContainer Title:\033[0m"
    echo -n "  "
    echo "$json" | jq -r '."container-title"'
    echo -e "\033[36mCollection Title:\033[0m"
    echo -n "  "
    echo "$json" | jq -r '."collection-title"'
    echo -e "\033[36mIssued:\033[0m"
    echo -n "  "
    echo "$json" | jq -r '.issued."date-parts"[0] | join("-")'
}

# @cmd Search citation entries using fzf
# @flag --recent Show recent citations
# @alias f
# @meta default-subcommand
find() {
    local index_filtered=""
    if [ "${argc_recent:-}" ]; then
        ids=$(cat "$CITREE_REPO/.citree/recent")
        index_filtered=$(awk -F '\t' '
            NR==FNR { order[$1] = ++n; next }
            $1 in order { lines[order[$1]] = $0 }
            END {
                for (i = 1; i <= n; i++) if (i in lines) print lines[i]
            }
        ' <(echo "$ids") "$CITREE_REPO/.citree/index")
    else
        index_filtered=$(cat "$CITREE_REPO/.citree/index")
    fi

    local selected=$(echo "$index_filtered" |
        fzf --with-nth=2 --bind "ctrl-o:execute(citree a {1})" \
            --bind "ctrl-e:execute(citree edit {1})+abort" \
            --delimiter="\t" --preview="citree show {1}")
    if [ -n "$selected" ]; then
        local id=$(echo "$selected" | awk -F '\t' '{print $1}')
        citree view "$id"
    fi
}

# @cmd Attach a file to a citation entry by ID
# @arg file!
# @arg id!
attach() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    mkdir -p "$CITREE_REPO/attachments/$argc_id"
    cp "$argc_file" "$CITREE_REPO/attachments/$argc_id/$(basename "$argc_file")"
}

# @cmd Search attachments for a given keyword using rga.
# @arg keyword!
search() {
    rga --files-with-matches "$argc_keyword" "$CITREE_REPO/attachments/"
}

# @cmd Add a new citation entry
# @option --doi <DOI> Use https://doi.org API to fetch citation information
# @flag --bibtex Use BibTeX format for input
add() {
    local bibtex=""
    if [ "${argc_bibtex:-}" ]; then
        bibtex=$(gum write --placeholder="Paste BibTeX here")
    else
        if [ -z "${argc_doi:-}" ]; then
            echo "error: missing --doi"
            exit 1
        fi
        bibtex=$(gum spin --title="Fetching from https://doi.org" -- curl -s -LH "Accept: application/x-bibtex" https://doi.org/$argc_doi)
        if [ $? -ne 0 ]; then
            echo "error: failed to fetch DOI information"
            exit 1
        fi
    fi
    local json=$(echo $bibtex | pandoc -f bibtex -t csljson)
    if [[ -z "$json" || "$json" == "[]" ]]; then
        echo "error: failed to parse citation information"
        exit 1
    fi
    local id=$(gennanoid)
    echo $json | jq ".[0]" | jq >"$CITREE_REPO/entries/$id.json"
    genindex
    updaterecent "$id"
    citree show "$id"
}

# @cmd Remove a citation entry by ID
# @arg id!
# @flag --prune Remove attachments as well
# @alias rm
remove() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    rm "$CITREE_REPO/entries/$argc_id.json"
    if [ "${argc_prune:-}" ]; then
        if [ -d "$CITREE_REPO/attachments/$argc_id" ]; then
            rm -rf "$CITREE_REPO/attachments/$argc_id"
        fi
    fi
    genindex
    echo "citation entry with ID $argc_id removed successfully"
}

# @cmd Edit a citation entry by ID
# @arg id!
edit() {
    editor="${EDITOR:-vim}"
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    local json=$(<"$CITREE_REPO/entries/$argc_id.json")
    echo "$json" | jq '.' >"$CITREE_REPO/entries/$argc_id.tmp.json"
    $editor "$CITREE_REPO/entries/$argc_id.tmp.json"
    if [ $? -ne 0 ]; then
        echo "error: failed to edit citation entry"
        exit 1
    fi
    # show diff
    local diff_output=$(diff --color=always -u "$CITREE_REPO/entries/$argc_id.json" "$CITREE_REPO/entries/$argc_id.tmp.json")
    if [ -n "$diff_output" ]; then
        echo "$diff_output"
    else
        echo "no changes made to the citation entry"
        rm "$CITREE_REPO/entries/$argc_id.tmp.json"
        return
    fi
    mv "$CITREE_REPO/entries/$argc_id.tmp.json" "$CITREE_REPO/entries/$argc_id.json"
    genindex
    updaterecent "$argc_id"
}

# @cmd Open PDF file in the default viewer
# @arg id!
view() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    if [ ! -d "$CITREE_REPO/attachments/$argc_id" ]; then
        echo "error: no attachments found for citation ID $argc_id"
        exit 1
    fi
    first_file=$(ls -t "$CITREE_REPO/attachments/$argc_id" | head -n 1)
    if [ -z "$first_file" ]; then
        echo "error: no files found in attachment directory"
        exit 1
    fi
    updaterecent "$argc_id"
    open "$CITREE_REPO/attachments/$argc_id/$first_file"
}

# @cmd Open attachments directory for a citation entry
# @arg id!
# @alias a
attachments() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.json" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    if [ ! -d "$CITREE_REPO/attachments/$argc_id" ]; then
        mkdir -p "$CITREE_REPO/attachments/$argc_id"
    fi
    open "$CITREE_REPO/attachments/$argc_id"
}

# @cmd Generate index of all citation entries
reindex() {
    genindex
    echo "index generated successfully"
}

_argc_before() {
    case "$argc__fn" in
    show | find | attach | search | add | view | attachments | reindex | remove | edit)
        dir=$(pwd)
        while [ "$dir" != "/" ] && [ ! -d "$dir/.citree" ]; do
            dir=$(dirname "$dir")
        done
        if [ -d "$dir/.citree" ]; then
            CITREE_REPO="$dir"
        elif [ -n "${CITREE_DEFAULT_REPO:-}" ] && [ -d "$CITREE_DEFAULT_REPO/.citree" ]; then
            CITREE_REPO="$CITREE_DEFAULT_REPO"
        else
            echo "error: not in a citree repository and CITREE_DEFAULT_REPO is not set or invalid"
            exit 1
        fi
        ;;
    esac

}

eval "$(argc --argc-eval "$0" "$@")"
