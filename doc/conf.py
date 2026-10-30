"""Sphinx configuration for wxvx4ufs documentation."""

project = "wxvx4ufs"
copyright = "2026, wxvx4ufs contributors"
author = "wxvx4ufs contributors"

extensions = ["myst_parser"]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

# Use Markdown for documentation pages.
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}

root_doc = "index"
html_theme = "sphinx_rtd_theme"
