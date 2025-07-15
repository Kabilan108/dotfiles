
## system info

the current machine runs nixos with a custom home-manager configuration.
tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

## Language-specific instructions

### `python`

#### code style

- use type hints wherever possible. if a @pyproject.toml file is present, check the pythonversion and use the appropriate type hints.
- the only code that belongs in a try except block, is the ccode that is expected to raise and exception.

### package management with uv

this project uses the `uv` package manager for dependency management:

#### common commands:
- `uv add <package>`: add a new dependency to pyproject.toml
- `uv add --group dev <package>`: add to development dependencies
- `uv remove <package>`: remove a dependency
- `uv sync`: install/update dependencies from lockfile
- `uv run <script>`: execute scripts in the project environment
- `uv run python <file>`: run python files with project dependencies

#### development workflow:
- dependencies are defined in `pyproject.toml`
- use `uv sync` to ensure environment matches lockfile
- use `uv run` to execute code with proper dependencies
- add new dependencies with `uv add` rather than manual editing

### `lua`

- write type annotations for function defnitions
- make sure to define a type/class annotation for types/classes that are used in multiple places
