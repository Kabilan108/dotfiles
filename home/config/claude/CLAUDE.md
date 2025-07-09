
## system info

the current machine runs nixos with a custom home-manager configuration.
tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

## Language-specific instructions

### `python`

#### code style

- use type hints wherever possible. if a @pyproject.toml file is present, check the pythonversion and use the appropriate type hints.
- the only code that belongs in a try except block, is the ccode that is expected to raise and exception.

#### package management

- use the `uv` package manager to manage python. 
- when necessary, uv will be installed via the project's flake.
- when you need to use uv, refer to the instructions here first. if relevant instructions are not available here, refer to the following url which provides links to more thorough documentation: https://docs.astral.sh/uv/llms.txt

- here are some examples of common operations you may need to perform:

### `lua`

- write type annotations for function defnitions
- make sure to define a type/class annotation for types/classes that are used in multiple places
