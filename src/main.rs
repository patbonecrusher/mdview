mod config;
mod markdown;
mod plantuml;
mod viewer;
mod watcher;

use clap::Parser;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "mdviewer", about = "Markdown viewer with diagram support")]
struct Args {
    /// Path to the markdown file to view
    file: Option<PathBuf>,

    /// Theme: auto, light, dark, modest, modest-dark
    #[arg(short, long)]
    theme: Option<String>,

    /// Font family
    #[arg(long)]
    font: Option<String>,

    /// Font size in pixels
    #[arg(long)]
    font_size: Option<u32>,
}

fn main() {
    let args = Args::parse();

    let file = args.file.map(|f| {
        std::fs::canonicalize(&f).unwrap_or_else(|e| {
            eprintln!("Error: cannot open '{}': {}", f.display(), e);
            std::process::exit(1);
        })
    });

    let mut config = config::Config::load();

    if let Some(theme) = &args.theme {
        config.theme = config::Theme::from_name(theme);
    }
    if let Some(font) = &args.font {
        config.font_family = font.clone();
    }
    if let Some(size) = args.font_size {
        config.font_size = size;
    }

    viewer::run(file, config);
}
