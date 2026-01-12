#!/usr/bin/env python3
"""
Build script for MkDocs documentation.
Parses all markdown files and assets in subfolders and generates the docs structure.
"""

import os
import shutil
import glob
import re
import yaml

# Configuration
DOCS_DIR = 'docs'
MKDOCS_CONFIG = 'mkdocs.yml'
EXCLUDE_DIRS = {'macros', 'templates', '.git', '__pycache__', 'docs', 'site'}
ASSET_EXTENSIONS = {'.svg', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.pdf'}


def clean_docs_dir():
    """Remove and recreate the docs directory."""
    if os.path.exists(DOCS_DIR):
        shutil.rmtree(DOCS_DIR)
    os.makedirs(DOCS_DIR)


def get_project_dirs():
    """Get all project directories (excluding special folders)."""
    projects = []
    for item in os.listdir('.'):
        if os.path.isdir(item) and item not in EXCLUDE_DIRS and not item.startswith('.'):
            projects.append(item)
    return sorted(projects)


def find_markdown_files(project_dir):
    """Find all markdown files in a project directory."""
    md_files = glob.glob(os.path.join(project_dir, '*.md'))
    return sorted(md_files)


def find_assets(project_dir):
    """Find all asset files (images, SVGs, PDFs) in a project directory."""
    assets = []
    
    # Check main directory
    for file in os.listdir(project_dir):
        filepath = os.path.join(project_dir, file)
        if os.path.isfile(filepath):
            ext = os.path.splitext(file)[1].lower()
            if ext in ASSET_EXTENSIONS:
                assets.append(filepath)
    
    # Check subdirectories (svg, images)
    for subdir in ['svg', 'images']:
        subdir_path = os.path.join(project_dir, subdir)
        if os.path.exists(subdir_path):
            for file in os.listdir(subdir_path):
                filepath = os.path.join(subdir_path, file)
                if os.path.isfile(filepath):
                    ext = os.path.splitext(file)[1].lower()
                    if ext in ASSET_EXTENSIONS:
                        assets.append(filepath)
    
    return assets


def copy_assets(project_dir, dest_project_dir):
    """Copy all assets from project to docs folder, maintaining structure."""
    assets = find_assets(project_dir)
    
    for asset in assets:
        # Get relative path from project dir
        rel_path = os.path.relpath(asset, project_dir)
        dest_path = os.path.join(dest_project_dir, rel_path)
        
        # Create destination directory if needed
        dest_dir = os.path.dirname(dest_path)
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
        
        # Copy the file
        shutil.copy2(asset, dest_path)
        print(f"  Copied: {rel_path}")


def process_markdown(md_file, project_dir, dest_project_dir):
    """Process a markdown file, updating asset paths and copying to docs."""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Markdown files reference assets relative to themselves, which should work
    # since we copy the assets maintaining the same structure
    
    # Get destination path
    md_filename = os.path.basename(md_file)
    dest_path = os.path.join(dest_project_dir, md_filename)
    
    # Write processed content
    with open(dest_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  Processed: {md_filename}")
    return md_filename


def create_project_index(project_dir, dest_project_dir, md_files):
    """Create an index.md for projects without markdown files."""
    project_name = project_dir.replace('_', ' ').replace('-', ' ').title()
    
    content = [f"# {project_name}\n"]
    
    # Check for FreeCAD files
    fcstd_files = glob.glob(os.path.join(project_dir, '*.FCStd'))
    if fcstd_files:
        content.append("## Project Files\n")
        for f in fcstd_files:
            fname = os.path.basename(f)
            content.append(f"- **FreeCAD:** {fname}")
        content.append("")
    
    # Check for PDF files
    pdf_files = glob.glob(os.path.join(project_dir, '*.pdf'))
    if pdf_files:
        content.append("## Documentation\n")
        for f in pdf_files:
            fname = os.path.basename(f)
            content.append(f"- [{fname}]({fname})")
        content.append("")
    
    # Check for SVG drawings
    svg_dir = os.path.join(project_dir, 'svg')
    if os.path.exists(svg_dir):
        svg_files = sorted(glob.glob(os.path.join(svg_dir, '*.svg')))
        if svg_files:
            content.append("## Drawings\n")
            for svg in svg_files:
                svg_name = os.path.basename(svg)
                title = os.path.splitext(svg_name)[0].replace('_', ' ')
                content.append(f"### {title}\n")
                content.append(f"![{title}](svg/{svg_name})\n")
    
    # Check for images
    images_dir = os.path.join(project_dir, 'images')
    if os.path.exists(images_dir):
        image_files = []
        for ext in ['*.jpg', '*.jpeg', '*.png', '*.gif', '*.webp']:
            image_files.extend(glob.glob(os.path.join(images_dir, ext)))
            image_files.extend(glob.glob(os.path.join(images_dir, ext.upper())))
        image_files.sort()
        
        if image_files:
            content.append("## Images\n")
            for img in image_files:
                img_name = os.path.basename(img)
                title = os.path.splitext(img_name)[0].replace('_', ' ').replace('-', ' ')
                content.append(f"### {title}\n")
                content.append(f"![{title}](images/{img_name})\n")
    
    # Write index file
    index_path = os.path.join(dest_project_dir, 'index.md')
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(content))
    
    print(f"  Created: index.md")
    return 'index.md'


def create_home_index(projects):
    """Create the main index.md for the documentation home."""
    content = [
        "# Furniture Designs\n",
        "Welcome to the furniture designs documentation. This site contains technical drawings ",
        "and specifications for various woodworking projects created with FreeCAD.\n",
        "## Projects\n"
    ]
    
    for project in projects:
        project_title = project.replace('_', ' ').replace('-', ' ').title()
        content.append(f"- [{project_title}]({project}/index.md)")
    
    content.append("\n---\n")
    content.append("*Generated from FreeCAD design files.*\n")
    
    index_path = os.path.join(DOCS_DIR, 'index.md')
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(content))
    
    print("Created: docs/index.md")


def update_mkdocs_nav(projects, project_pages):
    """Update mkdocs.yml with the navigation structure."""
    # Read existing config
    with open(MKDOCS_CONFIG, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    # Build navigation
    nav = [{'Home': 'index.md'}]
    
    for project in projects:
        project_title = project.replace('_', ' ').replace('-', ' ').title()
        pages = project_pages.get(project, ['index.md'])
        
        if len(pages) == 1:
            # Single page project
            nav.append({project_title: f"{project}/{pages[0]}"})
        else:
            # Multi-page project
            sub_nav = []
            for page in pages:
                page_title = os.path.splitext(page)[0].replace('_', ' ').title()
                if page == 'index.md':
                    page_title = 'Overview'
                sub_nav.append({page_title: f"{project}/{page}"})
            nav.append({project_title: sub_nav})
    
    config['nav'] = nav
    
    # Write updated config
    with open(MKDOCS_CONFIG, 'w', encoding='utf-8') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    print(f"Updated: {MKDOCS_CONFIG}")


def main():
    """Main build process."""
    print("Building MkDocs documentation...\n")
    
    # Clean and create docs directory
    clean_docs_dir()
    print(f"Created: {DOCS_DIR}/\n")
    
    # Get all project directories
    projects = get_project_dirs()
    print(f"Found {len(projects)} projects: {', '.join(projects)}\n")
    
    project_pages = {}
    
    # Process each project
    for project in projects:
        print(f"Processing: {project}/")
        
        # Create project directory in docs
        dest_project_dir = os.path.join(DOCS_DIR, project)
        os.makedirs(dest_project_dir)
        
        # Copy assets
        copy_assets(project, dest_project_dir)
        
        # Find and process markdown files
        md_files = find_markdown_files(project)
        pages = []
        
        for md_file in md_files:
            page = process_markdown(md_file, project, dest_project_dir)
            pages.append(page)
        
        # Create index if no markdown files exist
        if not md_files:
            page = create_project_index(project, dest_project_dir, md_files)
            pages.insert(0, page)
        elif 'index.md' not in [os.path.basename(f) for f in md_files]:
            # Rename the first markdown file or create an index
            if pages:
                # Use the first MD file as the main page
                main_page = pages[0]
                pages.insert(0, main_page)
            else:
                page = create_project_index(project, dest_project_dir, md_files)
                pages.insert(0, page)
        
        project_pages[project] = pages
        print()
    
    # Create home index
    create_home_index(projects)
    print()
    
    # Update mkdocs.yml navigation
    update_mkdocs_nav(projects, project_pages)
    
    print("\nBuild complete!")
    print(f"Run 'mkdocs serve' to preview the documentation.")
    print(f"Run 'mkdocs build' to generate the static site.")


if __name__ == '__main__':
    main()

