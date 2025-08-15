import Foundation
import os.log

class UsageTracker {
    static let shared = UsageTracker()
    
    private let logger = AppLogger.usageTracker
    private let fileManager = FileManager.default
    private let fileName = "usage_data.json"
    
    private var usageData: [String: UsageRecord] = [:]
    private let queue = DispatchQueue(label: "com.trace.usagetracker", attributes: .concurrent)
    private let saveDebouncer = Debouncer(delay: 1.0)
    
    private var dataFileURL: URL? {
        let directory = AppConstants.appDataDirectory
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create app data directory: \(error)")
                return nil
            }
        }
        
        return directory.appendingPathComponent(fileName)
    }
    
    private init() {
        loadUsageData()
    }
    
    private func loadUsageData() {
        guard let url = dataFileURL,
              fileManager.fileExists(atPath: url.path) else {
            logger.info("No existing usage data found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            usageData = try JSONDecoder().decode([String: UsageRecord].self, from: data)
            logger.info("Loaded usage data with \(self.usageData.count) entries")
        } catch {
            logger.error("Failed to load usage data: \(error)")
        }
    }
    
    private func saveUsageData() {
        guard let url = dataFileURL else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(self.usageData)
                try data.write(to: url)
                self.logger.debug("Saved usage data")
            } catch {
                self.logger.error("Failed to save usage data: \(error)")
            }
        }
    }
    
    func recordUsage(for identifier: String, type: UsageType = .application) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if var record = self.usageData[identifier] {
                record.count += 1
                record.lastUsed = Date()
                self.usageData[identifier] = record
            } else {
                self.usageData[identifier] = UsageRecord(
                    identifier: identifier,
                    type: type,
                    count: 1,
                    lastUsed: Date(),
                    firstUsed: Date()
                )
            }
            
            self.logger.debug("Recorded usage for \(identifier): \(self.usageData[identifier]?.count ?? 0)")
            
            self.saveDebouncer.debounce { [weak self] in
                self?.saveUsageData()
            }
        }
    }
    
    func getUsageScore(for identifier: String) -> Double {
        queue.sync {
            guard let record = usageData[identifier] else { return 0.0 }
            
            let baseScore = Double(record.count)
            
            let daysSinceLastUse = Date().timeIntervalSince(record.lastUsed) / (24 * 60 * 60)
            let recencyMultiplier = max(0.5, 1.0 - (daysSinceLastUse / 30.0))
            
            let daysSinceFirstUse = Date().timeIntervalSince(record.firstUsed) / (24 * 60 * 60)
            let frequencyScore = daysSinceFirstUse > 0 ? baseScore / daysSinceFirstUse : baseScore
            
            return (baseScore * 0.5 + frequencyScore * 100 * 0.5) * recencyMultiplier
        }
    }
    
    func getAllUsageScores() -> [String: Double] {
        queue.sync {
            var scores: [String: Double] = [:]
            for (identifier, _) in usageData {
                scores[identifier] = getUsageScore(for: identifier)
            }
            return scores
        }
    }
    
    func clearUsageData() {
        queue.async(flags: .barrier) { [weak self] in
            self?.usageData.removeAll()
            self?.saveUsageData()
            self?.logger.info("Cleared all usage data")
        }
    }
}

struct UsageRecord: Codable {
    let identifier: String
    let type: UsageType
    var count: Int
    var lastUsed: Date
    let firstUsed: Date
}

enum UsageType: String, Codable {
    case application = "application"
    case command = "command"
    case webSearch = "webSearch"
}

class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}