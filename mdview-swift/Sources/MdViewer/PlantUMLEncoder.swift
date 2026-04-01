import Foundation
import Compression

enum PlantUMLEncoder {
    private static let alphabet: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")

    static func encode(_ text: String) -> String {
        let compressed = deflate(text)
        return encode64(compressed)
    }

    private static func deflate(_ text: String) -> Data {
        let sourceData = Data(text.utf8)
        // Use raw DEFLATE (no zlib header)
        let bufferSize = sourceData.count + 512
        var destinationBuffer = Data(count: bufferSize)

        let compressedSize = destinationBuffer.withUnsafeMutableBytes { destPtr in
            sourceData.withUnsafeBytes { srcPtr in
                compression_encode_buffer(
                    destPtr.bindMemory(to: UInt8.self).baseAddress!,
                    bufferSize,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    sourceData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        // compression_encode_buffer with COMPRESSION_ZLIB produces raw deflate
        return destinationBuffer.prefix(compressedSize)
    }

    private static func encode64(_ data: Data) -> String {
        var result = ""
        let bytes = [UInt8](data)
        let len = bytes.count
        var i = 0

        while i < len {
            let b0 = UInt32(bytes[i])
            let b1 = (i + 1 < len) ? UInt32(bytes[i + 1]) : 0
            let b2 = (i + 2 < len) ? UInt32(bytes[i + 2]) : 0

            result.append(alphabet[Int(b0 >> 2)])
            result.append(alphabet[Int(((b0 & 0x3) << 4) | (b1 >> 4))])
            result.append(alphabet[Int(((b1 & 0xF) << 2) | (b2 >> 6))])
            result.append(alphabet[Int(b2 & 0x3F)])

            i += 3
        }

        return result
    }
}
