#!/bin/bash
#
# Build script for MkDocs documentation.
# Parses all markdown files and assets in subfolders and generates the docs structure.
#

set -e

# Configuration
DOCS_DIR="docs"
MKDOCS_CONFIG="mkdocs.yml"
EXCLUDE_DIRS="macros|templates|\.git|__pycache__|docs|site"

# Convert project name to title case (replace _ and - with spaces)
to_title() {
    echo "$1" | sed 's/_/ /g; s/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

# Clean and create docs directory
clean_docs_dir() {
    echo "Building MkDocs documentation..."
    echo
    
    if [ -d "$DOCS_DIR" ]; then
        rm -rf "$DOCS_DIR"
    fi
    mkdir -p "$DOCS_DIR"
    echo "Created: $DOCS_DIR/"
    echo
}

# Get all project directories
get_project_dirs() {
    find . -maxdepth 1 -type d ! -name '.' | sed 's|^\./||' | grep -vE "^($EXCLUDE_DIRS)$" | grep -v '^\.' | sort
}

# Copy assets from project to docs folder
copy_assets() {
    local project_dir="$1"
    local dest_dir="$2"
    
    # Copy assets from main directory
    for ext in svg png jpg jpeg gif bmp webp pdf; do
        for file in "$project_dir"/*.$ext "$project_dir"/*.${ext^^} 2>/dev/null; do
            if [ -f "$file" ]; then
                cp "$file" "$dest_dir/"
                echo "  Copied: $(basename "$file")"
            fi
        done
    done
    
    # Copy svg subdirectory
    if [ -d "$project_dir/svg" ]; then
        mkdir -p "$dest_dir/svg"
        for file in "$project_dir/svg"/*.svg 2>/dev/null; do
            if [ -f "$file" ]; then
                cp "$file" "$dest_dir/svg/"
                echo "  Copied: svg/$(basename "$file")"
            fi
        done
    fi
    
    # Copy images subdirectory
    if [ -d "$project_dir/images" ]; then
        mkdir -p "$dest_dir/images"
        for ext in jpg jpeg png gif webp bmp; do
            for file in "$project_dir/images"/*.$ext "$project_dir/images"/*.${ext^^} 2>/dev/null; do
                if [ -f "$file" ]; then
                    cp "$file" "$dest_dir/images/"
                    echo "  Copied: images/$(basename "$file")"
                fi
            done
        done
    fi
}

# Process markdown files
process_markdown() {
    local md_file="$1"
    local dest_dir="$2"
    
    local filename=$(basename "$md_file")
    cp "$md_file" "$dest_dir/$filename"
    echo "  Processed: $filename"
    echo "$filename"
}

# Create project index.md
create_project_index() {
    local project_dir="$1"
    local dest_dir="$2"
    local project_title=$(to_title "$project_dir")
    
    local index_file="$dest_dir/index.md"
    
    # Header
    echo "# $project_title" > "$index_file"
    echo >> "$index_file"
    
    # FreeCAD files
    local fcstd_files=$(find "$project_dir" -maxdepth 1 -name "*.FCStd" 2>/dev/null | sort)
    if [ -n "$fcstd_files" ]; then
        echo "## Project Files" >> "$index_file"
        echo >> "$index_file"
        while IFS= read -r f; do
            if [ -n "$f" ]; then
                echo "- **FreeCAD:** $(basename "$f")" >> "$index_file"
            fi
        done <<< "$fcstd_files"
        echo >> "$index_file"
    fi
    
    # PDF files
    local pdf_files=$(find "$project_dir" -maxdepth 1 -name "*.pdf" 2>/dev/null | sort)
    if [ -n "$pdf_files" ]; then
        echo "## Documentation" >> "$index_file"
        echo >> "$index_file"
        while IFS= read -r f; do
            if [ -n "$f" ]; then
                local fname=$(basename "$f")
                echo "- [$fname]($fname)" >> "$index_file"
            fi
        done <<< "$pdf_files"
        echo >> "$index_file"
    fi
    
    # SVG drawings
    if [ -d "$project_dir/svg" ]; then
        local svg_files=$(find "$project_dir/svg" -name "*.svg" 2>/dev/null | sort)
        if [ -n "$svg_files" ]; then
            echo "## Drawings" >> "$index_file"
            echo >> "$index_file"
            while IFS= read -r svg; do
                if [ -n "$svg" ]; then
                    local svg_name=$(basename "$svg")
                    local title=$(echo "${svg_name%.*}" | sed 's/_/ /g')
                    echo "### $title" >> "$index_file"
                    echo >> "$index_file"
                    echo "![${title}](svg/${svg_name})" >> "$index_file"
                    echo >> "$index_file"
                fi
            done <<< "$svg_files"
        fi
    fi
    
    # Images
    if [ -d "$project_dir/images" ]; then
        local image_files=$(find "$project_dir/images" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null | sort)
        if [ -n "$image_files" ]; then
            echo "## Images" >> "$index_file"
            echo >> "$index_file"
            while IFS= read -r img; do
                if [ -n "$img" ]; then
                    local img_name=$(basename "$img")
                    local title=$(echo "${img_name%.*}" | sed 's/_/ /g; s/-/ /g')
                    echo "### $title" >> "$index_file"
                    echo >> "$index_file"
                    echo "![${title}](images/${img_name})" >> "$index_file"
                    echo >> "$index_file"
                fi
            done <<< "$image_files"
        fi
    fi
    
    echo "  Created: index.md"
}

# Create home index
create_home_index() {
    local index_file="$DOCS_DIR/index.md"
    
    cat > "$index_file" << 'EOF'
# Furniture Designs

Welcome to the furniture designs documentation. This site contains technical drawings and specifications for various woodworking projects created with FreeCAD.

## Projects

EOF
    
    for project in $(get_project_dirs); do
        local project_title=$(to_title "$project")
        echo "- [$project_title]($project/index.md)" >> "$index_file"
    done
    
    cat >> "$index_file" << 'EOF'

---

*Generated from FreeCAD design files.*
EOF
    
    echo "Created: docs/index.md"
}

# Update mkdocs.yml navigation
update_mkdocs_nav() {
    local projects="$1"
    
    # Create temporary file for new config
    local tmp_config=$(mktemp)
    
    # Read existing config until nav section
    awk '/^nav:/{exit} {print}' "$MKDOCS_CONFIG" > "$tmp_config"
    
    # Write navigation
    echo "nav:" >> "$tmp_config"
    echo "  - Home: index.md" >> "$tmp_config"
    
    for project in $projects; do
        local project_title=$(to_title "$project")
        
        # Check if project has markdown files
        local md_files=$(find "$DOCS_DIR/$project" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
        local md_count=$(echo "$md_files" | grep -c "\.md$" 2>/dev/null || echo "0")
        
        if [ "$md_count" -le 1 ]; then
            # Single page - find the main file
            local main_file="index.md"
            if [ -n "$md_files" ]; then
                main_file=$(basename "$(echo "$md_files" | head -1)")
            fi
            echo "  - $project_title: $project/$main_file" >> "$tmp_config"
        else
            # Multi-page project
            echo "  - $project_title:" >> "$tmp_config"
            while IFS= read -r md; do
                if [ -n "$md" ]; then
                    local page=$(basename "$md")
                    local page_title=$(echo "${page%.*}" | sed 's/_/ /g; s/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
                    if [ "$page" = "index.md" ]; then
                        page_title="Overview"
                    fi
                    echo "    - $page_title: $project/$page" >> "$tmp_config"
                fi
            done <<< "$md_files"
        fi
    done
    
    # Replace original config
    mv "$tmp_config" "$MKDOCS_CONFIG"
    
    echo "Updated: $MKDOCS_CONFIG"
}

# Main build process
main() {
    # Clean and create docs directory
    clean_docs_dir
    
    # Get all project directories
    local projects=$(get_project_dirs)
    local project_count=$(echo "$projects" | wc -l | tr -d ' ')
    echo "Found $project_count projects: $(echo $projects | tr '\n' ', ' | sed 's/, $//')"
    echo
    
    # Process each project
    for project in $projects; do
        echo "Processing: $project/"
        
        # Create project directory in docs
        local dest_dir="$DOCS_DIR/$project"
        mkdir -p "$dest_dir"
        
        # Copy assets
        copy_assets "$project" "$dest_dir"
        
        # Find and process markdown files
        local md_files=$(find "$project" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
        local has_md=false
        
        while IFS= read -r md_file; do
            if [ -n "$md_file" ] && [ -f "$md_file" ]; then
                process_markdown "$md_file" "$dest_dir" > /dev/null
                has_md=true
            fi
        done <<< "$md_files"
        
        # Create index if no markdown files exist
        if [ "$has_md" = false ]; then
            create_project_index "$project" "$dest_dir"
        fi
        
        echo
    done
    
    # Create home index
    create_home_index
    echo
    
    # Update mkdocs.yml navigation
    update_mkdocs_nav "$projects"
    
    echo
    echo "Build complete!"
    echo "Run 'mkdocs serve' to preview the documentation."
    echo "Run 'mkdocs build' to generate the static site."
}

# Run main
main

