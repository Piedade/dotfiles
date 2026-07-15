build_odoo_module() {
    local module_dirs=("${@:-.}")
    local module_dir module_dir_abs module dest

    for module_dir in "${module_dirs[@]}"; do
        module_dir_abs=$(cd "$module_dir" 2>/dev/null && pwd) || {
            echo "❌ Directory not found: $module_dir"
            continue
        }

        module=$(basename "$module_dir_abs")
        dest="$(dirname "$module_dir_abs")/${module}.tar.gz"

        tar -czf "$dest" \
            --exclude='*/node_modules' \
            --exclude='*/app' \
            --exclude='*/__pycache__' \
            --exclude='*.pyc' \
            --exclude='*/.pytest_cache' \
            -C "$(dirname "$module_dir_abs")" "$module"/

        echo "✅ Created: $dest"
    done
}
