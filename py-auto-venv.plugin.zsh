# -----------------------------------------------------------------
# Automatic virtual environment activation
#
# Hooked into `chpwd` (runs on every `cd`) to automatically
# activate/deactivate virtual environments when navigating into or
# out of subdirectories in `$PY_AUTO_VENV_BASE_DIR`.
#
# Detection order:
#   1. UV_PROJECT_ENVIRONMENT (filesystem check)
#   2. .venv directory (filesystem check)
#   3. Poetry centralized env (subprocess fallback)
# -----------------------------------------------------------------

_PY_AUTO_VENV_PROJECT_ROOT=""

_py_auto_venv() {
  local base_repo_dir="${PY_AUTO_VENV_BASE_DIR:-/}"

  # Fast-path: still in same project
  if [[ -n "$VIRTUAL_ENV" && -n "$_PY_AUTO_VENV_PROJECT_ROOT" \
     && "$PWD"/ == "$_PY_AUTO_VENV_PROJECT_ROOT"/* ]]; then
    return
  fi

  # Only act inside base_repo_dir
  if [[ "$PWD"/ != "$base_repo_dir"/* ]]; then
    if [[ "$OLDPWD"/ == "$base_repo_dir"/* ]]; then
      if type deactivate &>/dev/null; then
        deactivate
        _PY_AUTO_VENV_PROJECT_ROOT=""
      fi
    fi
    return
  fi

  # Deactivate stale env before probing
  if type deactivate &>/dev/null; then
    deactivate
    _PY_AUTO_VENV_PROJECT_ROOT=""
  fi

  # Phase 1: Filesystem walk
  local dir="$PWD"
  local poetry_lock_dir=""
  while [[ "$dir"/ == "$base_repo_dir"/* ]]; do
    # 1. UV_PROJECT_ENVIRONMENT
    if [[ -n "$UV_PROJECT_ENVIRONMENT" ]]; then
      local uv_env=""
      if [[ "$UV_PROJECT_ENVIRONMENT" == /* ]]; then
        # Absolute: require project marker in this dir
        if [[ -f "$dir/pyproject.toml" || -f "$dir/uv.lock" ]]; then
          uv_env="$UV_PROJECT_ENVIRONMENT"
        fi
      else
        uv_env="$dir/$UV_PROJECT_ENVIRONMENT"
      fi
      if [[ -n "$uv_env" && -f "$uv_env/bin/activate" ]]; then
        source "$uv_env/bin/activate"
        _PY_AUTO_VENV_PROJECT_ROOT="$dir"
        return
      fi
    fi

    # 2. .venv
    if [[ -f "$dir/.venv/bin/activate" ]]; then
      source "$dir/.venv/bin/activate"
      _PY_AUTO_VENV_PROJECT_ROOT="$dir"
      return
    fi

    # Note poetry.lock for the subprocess fallback
    if [[ -z "$poetry_lock_dir" && -f "$dir/poetry.lock" ]]; then
      poetry_lock_dir="$dir"
    fi

    [[ "$dir" == "$base_repo_dir" ]] && break
    dir=$(dirname "$dir")
  done

  # Phase 2: Poetry fallback (centralized venv storage)
  # Only runs if we saw a poetry.lock during the walk and poetry is installed.
  if [[ -n "$poetry_lock_dir" ]] && command -v poetry &>/dev/null; then
    local env_path
    env_path=$(cd "$poetry_lock_dir" && poetry env info --path 2>/dev/null)
    if [[ $? -eq 0 && -n "$env_path" && -f "$env_path/bin/activate" ]]; then
      source "$env_path/bin/activate"
      _PY_AUTO_VENV_PROJECT_ROOT="$poetry_lock_dir"
    fi
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _py_auto_venv
