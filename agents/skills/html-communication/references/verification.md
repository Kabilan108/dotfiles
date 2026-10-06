# Artifact checks

Run the lint and decide on each warning. Verify changed content and links. Render new or materially changed layouts where readability needs inspection: diagrams for crossed arrows and clipped labels, charts against their data, mockups for clipping. Test the controls you changed. Choose viewport checks for the likely reader rather than a fixed matrix.

When publishing, check interactive behaviour in the PageBin viewer, not only the local file: the viewer frames the artifact in a sandbox with an opaque origin. For stateful controls, exercise the storage-denied and clipboard-unavailable paths. Keep the result usable in memory and provide selectable text or a download when copy is unavailable. Verify the published identity and content through PageBin when publishing. A text-only update to a previously checked layout does not require repeating every visual check.
