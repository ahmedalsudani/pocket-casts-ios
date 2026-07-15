# Source this file to use the project-local Bundler in fish:
#   source env.fish
#
# Installs into / reads from the gitignored .gems directory so nothing
# touches the system-wide gem directory.

set -l env_root (dirname (status --current-filename))
set env_root (cd $env_root; and pwd)

set -gx GEM_HOME "$env_root/.gems"
set -gx GEM_PATH "$env_root/.gems"
set -gx PATH "$env_root/.gems/bin" $PATH
