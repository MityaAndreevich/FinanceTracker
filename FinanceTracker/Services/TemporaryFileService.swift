//
//  TemporaryFileService.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 18.01.2026.
//

import Foundation

struct TemporaryFileService {
    static func writeTemporaryFile(data: Data, filename: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
        let url = folder.appendingPathComponent(filename)

        // Перезаписываем, если файл уже был
        try data.write(to: url, options: .atomic)

        return url
    }
}
