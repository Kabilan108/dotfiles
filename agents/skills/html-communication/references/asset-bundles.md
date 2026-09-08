# Asset bundles

Use separate assets when they make the artifact clearer or easier to maintain. Keep small artifacts inline; neither directory names nor gallery layouts are prescribed.

```sh
pagebin publish ./report/index.html --assets ./report/pictures --verify --json
pagebin update ./report/index.html --json
```

Check the installed `pagebin skill` and command help for more detailed usage info.

`--assets` is repeatable and recursively includes every regular file in each selected directory under its basename. For that example, reference `pictures/variant.png` in the HTML. PageBin does not crawl HTML for assets. Select only directories intended for publication; do not include a repository or unrelated logs as an asset root.

Receipts remember directories for update, watch, and verify. Supply them again on another machine; an explicit list replaces the remembered list. Deleted local assets disappear from the next version while retained versions preserve their bundles. Verify the bundle, including changed attachments, using the version-matched CLI instructions.
