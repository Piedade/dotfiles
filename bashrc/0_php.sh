# Function to search for a .phprc file and set PHP_BIN
autoload_php() {
  local dir="$PWD"
  local php_bin

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.phprc" ]]; then
      php_bin=php$(<"$dir/.phprc")
      if command -v "$php_bin" >/dev/null 2>&1; then
        export PHP_BIN="$php_bin"
        # echo "[phprc] Using PHP: $PHP_BIN"
        return
      else
        echo "[.phprc] Invalid PHP binary: $php_bin"
        break
      fi
    fi
    dir=$(dirname "$dir")
  done

  # No .phprc found or invalid: fallback
  export PHP_BIN="/usr/bin/php"
  # echo "[phprc] Using default PHP: $PHP_BIN"
}

# Override php command to use PHP_BIN
php() {
  "$PHP_BIN" "$@"
}

# Run autoload_php every time you change directory
PROMPT_COMMAND="autoload_php;$PROMPT_COMMAND"
