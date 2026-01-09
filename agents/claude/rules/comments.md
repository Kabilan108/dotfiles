---
globs: ["*.ts", "*.tsx", "*.js", "*.jsx", "*.py", "*.go", "*.nix", "*.lua"]
description: Comment policy
alwaysApply: true
---

## Comment Policy

### Unacceptable Comments

- Comments that repeat what the code does
- Commented-out code (delete it)
- Obvious comments ("increment counter")
- Comments instead of good naming
- Comments about updates to old code ("<- now supports xyz")

### Principle

Code should be self-documenting. If you need a comment to explain WHAT the code does,
consider refactoring to make it clearer.
