#!/usr/bin/env bash
# @describe Citree - A simple command-line citation manager (Yachen Mao)
# @meta version 0.1.0
# @meta require-tools yq,pandoc,curl,fzf,rga,gum

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
    for file in $(ls -1t $CITREE_REPO/entries/*.yml); do
        if [ -f "$file" ]; then
            local id=$(basename "$file" .yml)
            local metadata=$(<"$file")
            local title=$(echo "$metadata" | yq -r '.title')
            local authors=$(echo "$metadata" | yq -r '[.author[] | .given + " " + .family] | join(", ")' 2>/dev/null || echo "Unknown Author")
            local issued=$(echo "$metadata" | yq -r '.issued["date-parts"][0] | join("-")')
            local journal=$(echo "$metadata" | yq -r '."container-title"')
            local collection=$(echo "$metadata" | yq -r '."collection-title"')
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
        grep -vxF -- "$id" "$recent_file"
    } | head -n 50 >"$recent_file.tmp"
    mv "$recent_file.tmp" "$recent_file"
}

reffmt() {
    local id="$1"
    local metadata=$(<"$CITREE_REPO/entries/$id.yml")
    local refid=$(echo "$metadata" | yq -r '.id')
    metadata=$(yq eval-all '{"references": [select(fileIndex == 0)]}' <(echo "$metadata"))
    local md=$(printf -- "---\n%s\n---\n[@%s]\n" "$metadata" "$refid")
    local content=$(printf -- "%s" "$md" | pandoc -f markdown --wrap=none --citeproc -t plain | tail -n +3)
    echo "$content"
}

rename() {
    local id="$1"
    if [ ! -f "$CITREE_REPO/entries/$id.yml" ]; then
        echo "error: citation entry with ID $id does not exist"
        exit 1
    fi
    local metadata=$(<"$CITREE_REPO/entries/$id.yml")
    local title=$(echo "$metadata" | yq -r '.title')
    local issued=$(echo "$metadata" | yq -r '.issued["date-parts"][0] | join("-")')
    local new_name="${issued}_${title}"
    # Replace problematic characters in filename
    new_name=$(echo -n "$new_name" | tr -cs '[:alnum:]-' '_')
    if [ -d "$CITREE_REPO/attachments/$id" ]; then
        first_pdf=$(ls -t "$CITREE_REPO/attachments/$id"/*.pdf 2>/dev/null | head -n 1)
        if [ -n "$first_pdf" ]; then
            mv "$first_pdf" "$CITREE_REPO/attachments/$id/$new_name.pdf"
        fi
    fi
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
# @flag --plain Show plain text format
show() {
    if [ "${argc_plain:-}" ]; then
        reffmt "$argc_id"
        return
    fi
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
        echo "error: citation entry with ID $argc_id does not exist."
        exit 1
    fi
    local metadata=$(<"$CITREE_REPO/entries/$argc_id.yml")
    echo -e "\033[36mID:\033[0m"
    echo -n "  "
    echo -e "\033[1m$argc_id\033[0m"
    echo -e "\033[36mTitle:\033[0m"
    echo -n "  "
    echo -e "\033[1m$(echo "$metadata" | yq -r .title)\033[0m"
    if echo "$metadata" | yq -e '.author?' >/dev/null; then
        echo -e "\033[36mAuthors:\033[0m"
        echo "$metadata" | yq -r '.author[] | select(.given != null and .family != null) | "  " + .given + " " + .family'
    fi
    echo -e "\033[36mContainer Title:\033[0m"
    echo -n "  "
    echo "$metadata" | yq -r '."container-title"'
    echo -e "\033[36mCollection Title:\033[0m"
    echo -n "  "
    echo "$metadata" | yq -r '."collection-title"'
    echo -e "\033[36mIssued:\033[0m"
    echo -n "  "
    echo "$metadata" | yq -r '.issued."date-parts"[0] | join("-")'
    echo -e "\033[36mURL:\033[0m"
    echo -n "  "
    echo "$metadata" | yq -r '.URL'
    echo -e "\033[36mAttachments:\033[0m"
    if [ -d "$CITREE_REPO/attachments/$argc_id" ]; then
        local attachments=$(ls -1 "$CITREE_REPO/attachments/$argc_id" | sed 's/^/  /')
        if [ -z "$attachments" ]; then
            echo "  No attachments found"
        else
            echo "$attachments"
        fi
    else
        echo "  No attachments found"
    fi
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
        fzf --no-mouse --exact --with-nth="2..-1" --preview-window wrap \
            --bind "ctrl-o:execute(citree a {1})" \
            --bind "ctrl-e:execute(citree edit {1})+abort" \
            --delimiter="\t" --preview="citree show -- {1}")
    if [ -n "$selected" ]; then
        local id=$(echo "$selected" | awk -F '\t' '{print $1}')
        citree view "$id"
    fi
}

# @cmd Attach a file to a citation entry by ID
# @flag --rename Rename the attachment to match the citation entry
# @arg id!
# @arg file
attach() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    if [ "${argc_rename:-}" ]; then
        rename "$argc_id"
        return
    fi
    mkdir -p "$CITREE_REPO/attachments/$argc_id"
    cp "$argc_file" "$CITREE_REPO/attachments/$argc_id/$(basename "$argc_file")"
}

# @cmd Search for attachments using rga and fzf
search() {
    local attachments_dir="$CITREE_REPO/attachments"
    if [ ! -d "$attachments_dir" ]; then
        echo "No attachments directory found"
        exit 1
    fi
    local rga_cmd="rga --files-with-matches --rga-cache-max-blob-len=10M"

    local preview_cmd="rga --pretty --context 5 {q} $attachments_dir/{}"

    local selected=$(FZF_DEFAULT_COMMAND="$rga_cmd '' $attachments_dir | sed \"s|$attachments_dir/||\"" \
        fzf --exact --preview="$preview_cmd" \
        --preview-window wrap \
        --phony \
        --bind "change:reload:$rga_cmd {q} $attachments_dir | sed 's|$attachments_dir/||'")
    if [ -n "$selected" ]; then
        open "$attachments_dir/$selected"
    fi
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
    echo $json | yq ".[0]" | yq -P >"$CITREE_REPO/entries/$id.yml"
    genindex
    updaterecent "$id"
    citree show "$id"
}

# @cmd Remove a citation entry by ID
# @arg id!
# @flag --prune Remove attachments as well
# @alias rm
remove() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    rm "$CITREE_REPO/entries/$argc_id.yml"
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
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
        echo "error: citation entry with ID $argc_id does not exist"
        exit 1
    fi
    local metadata=$(<"$CITREE_REPO/entries/$argc_id.yml")
    echo "$metadata" | yq '.' >"$CITREE_REPO/entries/$argc_id.tmp.yml"
    $editor "$CITREE_REPO/entries/$argc_id.tmp.yml"
    if [ $? -ne 0 ]; then
        echo "error: failed to edit citation entry"
        exit 1
    fi
    # show diff
    local diff_output=$(diff --color=always -u "$CITREE_REPO/entries/$argc_id.yml" "$CITREE_REPO/entries/$argc_id.tmp.yml")
    if [ -n "$diff_output" ]; then
        echo "$diff_output"
    else
        echo "no changes made to the citation entry"
        rm "$CITREE_REPO/entries/$argc_id.tmp.yml"
        return
    fi
    mv "$CITREE_REPO/entries/$argc_id.tmp.yml" "$CITREE_REPO/entries/$argc_id.json"
    genindex
    updaterecent "$argc_id"
}

# @cmd Open PDF file in the default viewer
# @arg id!
view() {
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
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
    if [ ! -f "$CITREE_REPO/entries/$argc_id.yml" ]; then
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
