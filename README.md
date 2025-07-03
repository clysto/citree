# Citree: A Minimalist Command-Line Citation Manager

> Why use a heavy tool that doesn’t feel right, when Bash does it better?

## 😤 The Problem with Zotero and EndNote

Modern academic reference managers like Zotero and EndNote have become bloated.  
They require full desktop GUIs, constant syncing, proprietary databases, and often feel sluggish and overcomplicated — especially when all you want is to **fetch, search, view, and cite** efficiently.

Despite their heavyweight nature, these tools offer painfully weak search capabilities — nowhere near the instant fuzzy and full-text power of `fzf`, `ripgrep`, or `rga` beloved by terminal-first researchers.

## 💡 The Citree Philosophy

**Citree** is a lightweight, Unix-style alternative to citation management.  
It’s built entirely from:

- Bash scripts
- Powerful CLI tools (`jq`, `fzf`, `pandoc`, `curl`, `gum`, `rga`, etc.)
- Plain-text and JSON
- Zero dependencies beyond the command-line ecosystem

**With Citree, you own your citations. You control them. You search, edit, and attach with keyboard speed.**
No cloud accounts. No sync errors. No lock-in. Just a small set of scripts that **outperform Zotero** in daily research tasks.

## 🚀 Features

- 📌 **Add** citations via DOI or pasted BibTeX
- 📂 **Attach** local PDFs to entries
- 🔎 **Find/Search** entries instantly with `fzf` (and optionally `rga`)
- 🧾 **View** citation metadata in styled CLI output
- 📝 **Edit** entries with your favorite editor, with JSON diff preview
- 📋 **Recent** citation tracking
- 📚 **Index** and re-index citations into a fast tab-delimited database
- 🧼 **Remove** entries and clean associated files
- 🛠 Built entirely from standard tools, no lock-in, works offline

## 🛠 Requirements

Make sure the following tools are available in your `$PATH`:

- `bash` (v4+)
- `jq`
- `pandoc`
- `curl`
- `fzf`
- `gum`
- `rga` (optional, for content search)

## 📦 Installation

Clone this repo:

```bash
git clone https://github.com/yourname/citree.git
cd citree
chmod +x citree.sh
```

Then either:
- Add `citree.sh` to your `$PATH`, or
- Create an alias in your `.bashrc`/`.zshrc`:

```bash
alias citree="/path/to/citree/citree.sh"
```

## 🧪 Usage Example

```bash
# Initialize a new citation repo
citree init

# Add a citation from DOI
citree add --doi 10.1109/tnet.2020.2964290

# Attach a local PDF
citree attach path/to/paper.pdf "<id>"

# Search and preview entries
citree find

# View one
citree show "<id>"

# Open recent entries
citree find --recent
```

## 🧠 Philosophy

Citree is not a clone of Zotero. It’s a new take on citation management:

- Everything is **local-first**
- Files are **readable and portable**
- Tools are **composable and transparent**
- Search is **instant**
- The interface is your **terminal**


It’s fast, minimal, and built for power users who prefer tools they can understand and control.


## 🔮 What's Next

You might have noticed — Citree currently supports only BibTeX and DOI-based citation imports. That doesn’t sound very powerful, does it?

In reality, importing metadata from the web is messy: websites use wildly different HTML structures, and scraping them reliably is hard. Zotero took years to maintain their massive translator library — and I’ve grown tired of chasing down small bugs across dozens of fragile site parsers.

Citree takes a different approach: this functionality will be **externalized into a plugin system**.

In the future, every metadata fetcher will be a standalone executable plugin. You can write one in any language you like. Given a URL or identifier, the plugin will convert it into CSL-JSON for Citree to consume.

Plugin support is currently under development.
