import Foundation
import Path
import TuistSupport
import XcodeGraph

/// Storage for run metadata, such as binary cache.
public actor RunMetadataStorage {
    @TaskLocal public static var current: RunMetadataStorage = .init()

    public init() {}

    /// A unique ID associated with a specific run
    public var runId: String { Environment.current.processId }
    /// Graph associated with the current run
    public private(set) var graph: Graph?
    public func update(graph: Graph?) {
        self.graph = graph
    }

    /// Binar cache-specific cache items
    public private(set) var binaryCacheItems: [AbsolutePath: [String: CacheItem]] = [:]
    public func update(binaryCacheItems: [AbsolutePath: [String: CacheItem]]) {
        self.binaryCacheItems = binaryCacheItems
    }

    /// Selective testing-specific cache items
    public private(set) var selectiveTestingCacheItems: [AbsolutePath: [String: CacheItem]] = [:]
    public func update(selectiveTestingCacheItems: [AbsolutePath: [String: CacheItem]]) {
        self.selectiveTestingCacheItems = selectiveTestingCacheItems
    }

    /// Preview associated with the current run
    public private(set) var previewId: String?
    public func update(previewId: String?) {
        self.previewId = previewId
    }

    /// Path to the result bundle that should be uploaded when running commands like `tuist xcodebuild test`
    public private(set) var resultBundlePath: AbsolutePath?
    public func update(resultBundlePath: AbsolutePath?) {
        self.resultBundlePath = resultBundlePath
    }
}
