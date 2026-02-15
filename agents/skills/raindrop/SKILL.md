---
name: raindrop
description: Manage Raindrop.io bookmarks using the raindrop CLI. Use when organizing, categorizing, tagging, or searching bookmarks.
allowed-tools: Bash(raindrop *)
---

# Raindrop CLI

CLI client for the Raindrop.io bookmark manager. Output is JSON by default. Add `--human` for table output. Add `--no-cache` to bypass the 5-minute disk cache.

## Workflow

A typical workflow for organizing a Raindrop library:

1. `raindrop collection list` and `raindrop filter get 0` to understand the current library state
2. `raindrop raindrop list 0 --all` to fetch every bookmark
3. `raindrop raindrop search 0 --query "..."` to find bookmarks matching a topic
4. `raindrop collection create --title "..."` to create organizational collections
5. `raindrop raindrop bulk-update <collectionId> --ids 1,2,3 --collection <newId> --tags "..."` to move and tag in batch
6. `raindrop tag merge` and `raindrop tag rename` to normalize taxonomy
7. `raindrop collection clean` to remove empty collections

## Special Collection IDs

- `0` — all bookmarks
- `-1` — unsorted
- `-99` — trash

## Commands

### config

```bash
raindrop config set token '${env:RAINDROP_TOKEN}'   # set token (env ref recommended)
raindrop config set token                            # set token (interactive prompt)
raindrop config get token                            # show current token (masked)
raindrop config verify                               # test credentials against API
```

### collection

```bash
raindrop collection list                                          # list all collections
raindrop collection get <id>                                      # get collection details
raindrop collection create --title "Name" [--view list|grid|simple|masonry] [--parent <id>] [--public]
raindrop collection update <id> [--title "New"] [--view grid] [--public] [--expanded] [--parent <id>] [--sort <n>]
raindrop collection delete <id>
raindrop collection merge --to <targetId> --ids 1,2,3             # merge collections into target
raindrop collection clean                                         # remove all empty collections
raindrop collection stats                                         # per-collection item counts
```

### raindrop

```bash
# List and paginate
raindrop raindrop list <collectionId>                             # list bookmarks (default: 25 per page)
raindrop raindrop list <collectionId> --per-page 50 --page 1      # paginate manually
raindrop raindrop list <collectionId> --all                       # fetch every page automatically
raindrop raindrop list <collectionId> --sort -created --nested    # sort and include nested collections

# CRUD
raindrop raindrop get <id>                                        # get single bookmark
raindrop raindrop create --link "https://..." [--title "..."] [--tags "go,cli"] [--collection <id>] [--parse] [--important]
raindrop raindrop update <id> [--title "..."] [--link "..."] [--tags "go,cli"] [--collection <id>] [--important] [--type "..."] [--cover "..."]
raindrop raindrop delete <id>

# Search (supports Raindrop operators: #tag, type:article, etc.)
raindrop raindrop search <collectionId> --query "golang" [--all] [--sort -created] [--nested]

# Suggestions (get AI-powered tag/collection suggestions)
raindrop raindrop suggest --link "https://..."                    # for a URL
raindrop raindrop suggest --id <id>                               # for an existing bookmark

# Bulk operations
raindrop raindrop bulk-update <collectionId> --ids 1,2,3 [--tags "reviewed"] [--collection <newId>] [--important]
raindrop raindrop bulk-delete <collectionId> --ids 1,2,3          # delete by IDs
raindrop raindrop bulk-delete <collectionId> --search "outdated"  # delete by search query
```

### tag

All tag commands accept an optional collection ID as the first argument. Omit it to operate across all collections.

```bash
raindrop tag list [collectionId]                                  # list all tags with counts
raindrop tag rename [collectionId] --from "golang" --to "go"      # rename a tag
raindrop tag merge [collectionId] --tags "golang,go-lang" --to "go"  # merge tags into one
raindrop tag delete [collectionId] --tags "deprecated,old"        # delete tags
```

### filter

```bash
raindrop filter get <collectionId>                                # broken, duplicates, important, untagged counts + tag/type breakdown
raindrop filter get <collectionId> --tags-sort -count             # sort tags by count (default)
raindrop filter get <collectionId> --tags-sort _id                # sort tags alphabetically
```

### highlight

```bash
raindrop highlight list [--collection <id>] [--page 0] [--per-page 25]
```

## Tips

- Use `bulk-update` to move and tag multiple bookmarks in a single API call — much faster than updating one by one.
- `filter get 0` gives a quick overview of library health: broken links, duplicates, untagged items, and tag/type distribution.
- `suggest --id <id>` returns AI-powered tag and collection suggestions from Raindrop — useful for auto-categorization.
- The `--all` flag on `list` and `search` auto-paginates through all results (50 per page internally).
- Tags on `update` and `bulk-update` replace all existing tags. To add a tag, include the existing tags in the list.
- The `--parse` flag on `create` tells Raindrop to auto-fill title, excerpt, and cover from the URL.
