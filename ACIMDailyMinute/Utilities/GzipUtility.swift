import Foundation
import Compression

enum GzipUtility {
    static func decompress(_ data: Data) -> Data? {
        // Skip gzip header (minimum 10 bytes)
        guard data.count > 10 else { return nil }

        // Find start of deflate stream (skip gzip header)
        var headerSize = 10
        let flags = data[3]

        // FEXTRA
        if flags & 0x04 != 0 {
            guard data.count > headerSize + 2 else { return nil }
            let extraLen = Int(data[headerSize]) | (Int(data[headerSize + 1]) << 8)
            headerSize += 2 + extraLen
        }
        // FNAME
        if flags & 0x08 != 0 {
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        // FCOMMENT
        if flags & 0x10 != 0 {
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        // FHCRC
        if flags & 0x02 != 0 {
            headerSize += 2
        }

        guard headerSize < data.count else { return nil }

        let compressedData = data.subdata(in: headerSize..<(data.count - 8)) // strip header and trailer
        let bufferSize = 1024 * 1024 // 1MB initial
        var outputData = Data(count: bufferSize)

        let result = compressedData.withUnsafeBytes { srcPtr -> Int in
            guard let srcBase = srcPtr.baseAddress else { return 0 }
            return outputData.withUnsafeMutableBytes { dstPtr -> Int in
                guard let dstBase = dstPtr.baseAddress else { return 0 }
                return compression_decode_buffer(
                    dstBase.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    srcBase.assumingMemoryBound(to: UInt8.self),
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result > 0 else { return nil }
        return outputData.prefix(result)
    }
}
