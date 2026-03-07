use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::sync::mpsc;

pub fn watch(path: &Path) -> (RecommendedWatcher, mpsc::Receiver<()>) {
    let (tx, rx) = mpsc::channel();
    let parent = path.parent().unwrap_or(path);

    let mut watcher = RecommendedWatcher::new(
        move |res: Result<Event, notify::Error>| {
            if let Ok(_event) = res {
                let _ = tx.send(());
            }
        },
        Config::default(),
    )
    .expect("Failed to create file watcher");

    watcher
        .watch(parent, RecursiveMode::NonRecursive)
        .expect("Failed to watch file");

    (watcher, rx)
}
