# py-auto-venv

Automatic virtual environment activation for zsh. When you `cd` into a Python project, your venv activates. When you leave, it deactivates. No manual `source .venv/bin/activate` required.

The common case -- navigating within a project that's already activated -- is a single string comparison with no filesystem checks and no subprocesses. Detection only runs when you actually change projects, and even then it tries pure filesystem lookups first and only shells out to external tools as a last resort. This keeps every `cd` fast regardless of how many tools you have installed.

Works with uv, Poetry, PDM, and plain `.venv` directories created by any tool (or by hand).

## Installation

| Plugin manager | Add to your `.zshrc` (or relevant config) |
|---|---|
| **[Antigen](https://github.com/zsh-users/antigen)** | `antigen bundle GuyAglionby/py-auto-venv` |
| **[Oh-My-Zsh](https://github.com/ohmyzsh/ohmyzsh)** | Clone: `git clone https://github.com/GuyAglionby/py-auto-venv ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/py-auto-venv`<br>Then add `py-auto-venv` to your `plugins=(...)` array |
| **[Sheldon](https://sheldon.cli.rs)** | Add to `~/.config/sheldon/plugins.toml`:<br>`[plugins.py-auto-venv]`<br>`github = "GuyAglionby/py-auto-venv"` |
| **[Zgenom](https://github.com/jandamm/zgenom)** | `zgenom load GuyAglionby/py-auto-venv` |
| **[Zinit](https://github.com/zdharma-continuum/zinit)** | `zinit light GuyAglionby/py-auto-venv` |
| **[Zplug](https://github.com/zplug/zplug)** | `zplug "GuyAglionby/py-auto-venv"` |
| **Manual** | `git clone https://github.com/GuyAglionby/py-auto-venv ~/.zsh/py-auto-venv`<br>Then add: `source ~/.zsh/py-auto-venv/py-auto-venv.plugin.zsh` |

## How it works

### Detection

When you enter a project, py-auto-venv walks up the directory tree from your current directory toward the projects directory, checking for virtual environments at each level:

- **`.venv` directory** -- checks for `.venv/bin/activate`. This is the convention used by uv (by default), PDM (with `pdm config venv.in-project true`), Poetry (with `virtualenvs.in-project true`), and manual `python -m venv .venv` setups. Because this check is tool-agnostic, it works regardless of which tool created the environment.

- **Custom uv environment location** -- uv lets you override the venv directory name via the `UV_PROJECT_ENVIRONMENT` environment variable (e.g. `.my-venv` instead of `.venv`). If this variable is set, py-auto-venv checks for it at each level of the walk alongside `.venv`. When `UV_PROJECT_ENVIRONMENT` is an absolute path (pointing somewhere outside the project), py-auto-venv requires a `pyproject.toml` or `uv.lock` in the directory to confirm it's actually a project root before activating.

- **Poetry centralized environments** -- Poetry can store virtual environments outside the project directory (e.g. in `~/.cache/pypoetry/virtualenvs/`), where the path includes an internal hash that can't be derived from the project files alone. If the filesystem walk finds a `poetry.lock` but no local venv, and `poetry` is installed, py-auto-venv runs `poetry env info --path` to resolve the environment location. This is the only case where a subprocess is spawned.

### Project root

The project root is the directory where the virtual environment was found: whichever directory in the walk contained the `.venv` (or custom uv environment), or the directory containing `poetry.lock` for centralized Poetry environments. When you `cd` out of the project root, the environment is deactivated.

### Projects directory

py-auto-venv hooks into zsh's `chpwd` mechanism, which fires on every directory change. To avoid unnecessary work, you can scope it to a **projects directory** -- the parent directory that contains all of your Python projects. Set `PY_AUTO_VENV_BASE_DIR` to this path:

```zsh
export PY_AUTO_VENV_BASE_DIR="$HOME/Documents/repos"
```

py-auto-venv will only run detection when you're inside this tree, and will automatically deactivate when you leave it. This defaults to `/` (the filesystem root), so it works everywhere out of the box -- but if your projects all live under one directory, setting this means `cd`-ing around the rest of your filesystem is completely untouched.

### Fast-path

Once a virtual environment is activated, navigating within that project (`cd src/`, `cd ../tests/`) skips all detection. py-auto-venv remembers the project root and checks whether your current directory is still under it -- a single string comparison with no filesystem access and no subprocesses.
