# Source this file to use the project-local Bundler in bash/zsh:
#   source env.sh
#
# Installs into / reads from the gitignored .gems directory so nothing
# touches the system-wide gem directory.

_env_root="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"

export GEM_HOME="$_env_root/.gems"
export GEM_PATH="$_env_root/.gems"
export PATH="$_env_root/.gems/bin:$PATH"

unset _env_root
