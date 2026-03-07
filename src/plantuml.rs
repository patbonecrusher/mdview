use flate2::write::DeflateEncoder;
use flate2::Compression;
use std::io::Write;

const PLANTUML_ALPHABET: &[u8] =
    b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_";

pub fn encode(text: &str) -> String {
    let compressed = deflate(text);
    encode64(&compressed)
}

fn deflate(text: &str) -> Vec<u8> {
    let mut encoder = DeflateEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(text.as_bytes()).unwrap();
    encoder.finish().unwrap()
}

fn encode64(data: &[u8]) -> String {
    let mut result = String::new();
    let len = data.len();
    let mut i = 0;

    while i < len {
        let b0 = data[i] as u32;
        let b1 = if i + 1 < len { data[i + 1] as u32 } else { 0 };
        let b2 = if i + 2 < len { data[i + 2] as u32 } else { 0 };

        result.push(PLANTUML_ALPHABET[(b0 >> 2) as usize] as char);
        result.push(PLANTUML_ALPHABET[(((b0 & 0x3) << 4) | (b1 >> 4)) as usize] as char);
        result.push(PLANTUML_ALPHABET[(((b1 & 0xF) << 2) | (b2 >> 6)) as usize] as char);
        result.push(PLANTUML_ALPHABET[(b2 & 0x3F) as usize] as char);

        i += 3;
    }

    result
}
