import Foundation

enum FFmpegCommandBuilder {
    static func compressionArguments(inputPath: String, outputPath: String) -> String {
        "-y -i \"\(inputPath)\" -c:v libx265 -crf 23 -preset medium -c:a copy -tag:v hvc1 \"\(outputPath)\""
    }
}
