# Raindrop bookmarks

Use the configured `raindrop_io` toolkit through Executor. It replaces the retired Raindrop CLI. Discover and describe tools live; the toolkit is not a one-to-one wrapper around the CLI.

## Finding and organizing

Start with the collections, tags, or bookmarks relevant to the request. Fetch the whole library only when the task needs complete coverage. Semantic search and misplaced/mistagged detection return candidates; verify relevance before selecting IDs for changes.

Bookmark search is paginated. Follow the described page convention and response metadata, use a stable sort for exhaustive scans, and report incomplete coverage. Collect the intended IDs before mutating a result set so moves or tag changes do not shift later pages. Describe current limits before batching; bookmark search and update currently support at most 150 results or bookmark IDs per call.

Use the toolkit's explicit filters and collection scope. Check nested-collection coverage and special collection IDs in the live tool documentation rather than carrying over CLI conventions. Fetch full bookmark content only when snippets are insufficient for the task.

## Changes

- Bookmark tags use `tags.add` and `tags.remove`. Preserve unrelated tags; for an explicit replacement, read existing tags and compute the differences.
- Bookmark creation currently accepts URL, title, note, and collection. Apply requested tags or favorite status to the returned IDs in a subsequent update. If that update fails, report the partial result instead of creating the bookmarks again.
- Tag rename/merge and delete tools operate globally. For changes confined to a collection, use tag deltas on the selected bookmarks.
- Bookmark deletion moves items to Trash; deleting items already in Trash permanently removes them. Collection deletion includes nested collections and moves their bookmarks to Trash. Collection merge moves source bookmarks and deletes the source collections.
- Empty-collection cleanup is a separate requested operation. Check descendants before deleting a collection with zero direct bookmarks.

After changes, verify the affected records and report any failed batches or unfinished steps. When a requested field or operation is absent from the current toolkit, state the gap rather than silently substituting a different operation.
