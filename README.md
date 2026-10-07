# lightcone-dev

lc and Lightcone Lab at chosen revisions. The flake provides a shell with
`lc`, `astra`, `lightcone-lab`, uv, git, git-annex and Node, and an app that
starts Lab. All of it is free software; the `claude` shell adds Claude Code
on top (see [Agents](#agents)).

## Set up a NixOS machine

Once, in the system configuration:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
programs.nix-ld.enable = true;
```

Rebuild, then log out and back in. On macOS and other Linux distributions,
only flakes need enabling.

## Start a project

```bash
nix develop github:charnock-fr/lightcone-dev
```

The shell provides git. If git has no identity on this machine yet, give it
one; lc commits every result:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.org"
```

Then:

```bash
mkdir my-analysis && cd my-analysis
lc init
```

Add `python-preference` to the `[tool.uv]` table `lc init` wrote in
`pyproject.toml` (see [Python on NixOS](#python-on-nixos)):

```toml
[tool.uv]
required-version = ">=0.12"
python-preference = "only-managed"
```

then commit:

```bash
git add -A && git commit -m "Start the analysis"
```

## Run Lab

In the shell, from the directory holding your projects, which becomes the
server root:

```bash
lightcone-lab --no-browser
```

Arguments go to `jupyter lab`. Without the shell:
`nix run github:charnock-fr/lightcone-dev -- --no-browser`.

The first run of a Lab revision builds its wheel into
`~/.cache/lightcone-dev/lab/`, which takes about a minute and needs the
network. Python packages resolve as published at the newer of the `lab` and
`lightcone` inputs' commit dates.

## Python on NixOS

uv installs its own CPython builds into `~/.local/share/uv/python`. They are
built for generic Linux, and NixOS runs them, and the compiled extensions in
PyPI wheels, through nix-ld. A Python from nixpkgs runs too, but those
extensions cannot find `libstdc++` from it, so an environment built on it
fails at import.

`lc`, `lightcone-lab` and the project kernel pass `--managed-python` to uv,
so they always use uv's Python. lc removes `UV_*` variables from the uv
commands it runs for a project, so for those the setting has to be in the
project: `python-preference = "only-managed"`. Without it, uv uses a nixpkgs
Python on `PATH` whose version matches `.python-version` when it has not
installed that version itself.

The setting travels with the project: everyone who works on it gets uv's own
build of the pinned Python, downloaded on first use, even where a system
Python of that version is installed. A machine that cannot download Python
needs uv's installed in advance.

## Kernels

The kernel "Python (project)" runs a notebook in the uv environment of the
project containing it, through `uv run --locked --with ipykernel`, so
ipykernel stays out of the project's lock. The default "Python 3" kernel is
Lab's own environment and has none of the project's packages.

## Agents

The `claude` shell is the default shell plus Claude Code and
`claude-agent-acp`, its adapter for Jupyter AI. Claude Code is unfree, and
the adapter's nixpkgs package wraps it; this shell allows `claude-code` and
nothing else.

```bash
nix develop github:charnock-fr/lightcone-dev#claude
claude                       # sign in once
lightcone-lab --no-browser
```

Lab offers the Claude agent only when started with `claude-agent-acp` on
`PATH`.

## Choose revisions

```bash
nix run github:charnock-fr/lightcone-dev --override-input lab github:charnock-fr/jupyterlab-lightcone/my-branch
nix run github:charnock-fr/lightcone-dev --override-input lightcone github:charnock-fr/lightcone-cli/my-branch
nix develop github:charnock-fr/lightcone-dev --override-input lab git+file:///path/to/jupyterlab-lightcone
```

A `git+file` input includes uncommitted changes to tracked files. The
`lightcone` input must provide `packages.<system>.default.dist`, the
directory holding lc's wheel. In a checkout of this repository,
`nix flake update lab` moves the pinned revision.

## Develop lc and Lab together

```bash
nix develop github:charnock-fr/lightcone-dev
uv venv --managed-python ~/.venvs/lab-dev
. ~/.venvs/lab-dev/bin/activate
cd /path/to/jupyterlab-lightcone
uv pip install -e ".[dev]" -e /path/to/lightcone-cli
jupyter-builder develop . --overwrite
jupyter server extension enable jupyterlab_lightcone
jlpm watch      # in one terminal
jupyter lab     # in another
```

Restart `jupyter lab` after Python changes in either repository, and reload
the browser after TypeScript changes.
