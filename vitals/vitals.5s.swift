#!/usr/bin/env swift

import Foundation
import Darwin
import IOKit

// MARK: - Memory Stats

struct MemoryStats {
    let pageSize: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let purgeable: UInt64
    let speculative: UInt64
    let total: UInt64
    let appMemory: UInt64
    let cachedFiles: UInt64

    var used: UInt64 {
        active + wired + compressed
    }

    var available: UInt64 {
        free + inactive + purgeable
    }
}

struct SwapStats {
    let used: UInt64
    let total: UInt64
}

struct CPUStats {
    let user: Double
    let system: Double
    let idle: Double
    let nice: Double

    var total: Double {
        user + system + nice
    }
}

// MARK: - System Info

func getSystemInfo() -> (model: String, chip: String, cores: Int, memory: String) {
    var model = "Mac"
    var chip = "Apple Silicon"

    // Get model
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var modelBuffer = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &modelBuffer, &size, nil, 0)
    model = String(cString: modelBuffer)

    // Get chip brand
    size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    if size > 0 {
        var brandBuffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brandBuffer, &size, nil, 0)
        chip = String(cString: brandBuffer)
    }

    // Get CPU cores
    var cores: Int32 = 0
    size = MemoryLayout<Int32>.size
    sysctlbyname("hw.ncpu", &cores, &size, nil, 0)

    // Get memory
    var memSize: UInt64 = 0
    size = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
    let memGB = memSize / 1_073_741_824

    return (model, chip, Int(cores), "\(memGB)GB")
}

func getMemoryStats() -> MemoryStats? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

    let result = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }

    guard result == KERN_SUCCESS else { return nil }

    let pageSize = UInt64(vm_kernel_page_size)

    var totalMem: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)

    let appMemory = (UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)) * pageSize
    let cachedFiles = (UInt64(stats.external_page_count) + UInt64(stats.purgeable_count)) * pageSize

    return MemoryStats(
        pageSize: pageSize,
        free: UInt64(stats.free_count) * pageSize,
        active: UInt64(stats.active_count) * pageSize,
        inactive: UInt64(stats.inactive_count) * pageSize,
        wired: UInt64(stats.wire_count) * pageSize,
        compressed: UInt64(stats.compressor_page_count) * pageSize,
        purgeable: UInt64(stats.purgeable_count) * pageSize,
        speculative: UInt64(stats.speculative_count) * pageSize,
        total: totalMem,
        appMemory: appMemory,
        cachedFiles: cachedFiles
    )
}

func getSwapStats() -> SwapStats? {
    var swapUsage = xsw_usage()
    var size = MemoryLayout<xsw_usage>.size

    guard sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0) == 0 else {
        return nil
    }

    return SwapStats(
        used: swapUsage.xsu_used,
        total: swapUsage.xsu_total
    )
}

func getMemoryPressure() -> String {
    var pressure: Int32 = 0
    var size = MemoryLayout<Int32>.size

    if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &size, nil, 0) == 0 {
        switch pressure {
        case 1: return "normal"
        case 2: return "warn"
        case 4: return "critical"
        default: return "normal"
        }
    }
    return "normal"
}

// MARK: - CPU Stats

var previousCPUInfo: processor_info_array_t?
var previousCPUInfoCount: mach_msg_type_number_t = 0

func getCPUUsage() -> CPUStats? {
    var numCPUs: natural_t = 0
    var cpuInfo: processor_info_array_t?
    var numCPUInfo: mach_msg_type_number_t = 0

    let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
    guard err == KERN_SUCCESS, let info = cpuInfo else { return nil }

    var totalUser: Double = 0
    var totalSystem: Double = 0
    var totalIdle: Double = 0
    var totalNice: Double = 0

    for i in 0..<Int(numCPUs) {
        let offset = Int(CPU_STATE_MAX) * i
        let user = Double(info[offset + Int(CPU_STATE_USER)])
        let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
        let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
        let nice = Double(info[offset + Int(CPU_STATE_NICE)])

        totalUser += user
        totalSystem += system
        totalIdle += idle
        totalNice += nice
    }

    let total = totalUser + totalSystem + totalIdle + totalNice
    guard total > 0 else { return nil }

    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size))

    return CPUStats(
        user: (totalUser / total) * 100,
        system: (totalSystem / total) * 100,
        idle: (totalIdle / total) * 100,
        nice: (totalNice / total) * 100
    )
}

func getLoadAverage() -> (Double, Double, Double)? {
    var loadAvg = [Double](repeating: 0, count: 3)
    guard getloadavg(&loadAvg, 3) == 3 else { return nil }
    return (loadAvg[0], loadAvg[1], loadAvg[2])
}

// MARK: - GPU Stats (Apple Silicon)

func getGPUUsage() -> Double? {
    let matching = IOServiceMatching("IOAccelerator")
    var iterator: io_iterator_t = 0

    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return nil
    }

    defer { IOObjectRelease(iterator) }

    var service = IOIteratorNext(iterator)
    while service != 0 {
        var properties: Unmanaged<CFMutableDictionary>?

        if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let dict = properties?.takeRetainedValue() as? [String: Any],
           let perfStats = dict["PerformanceStatistics"] as? [String: Any] {

            // Try different keys for GPU utilization
            if let gpuUtil = perfStats["GPU Activity(%)"] as? Double {
                IOObjectRelease(service)
                return gpuUtil
            }
            if let gpuUtil = perfStats["Device Utilization %"] as? Double {
                IOObjectRelease(service)
                return gpuUtil
            }
            if let gpuUtil = perfStats["hardwareWaitTime"] as? Double,
               let totalTime = perfStats["allGPUTime"] as? Double,
               totalTime > 0 {
                IOObjectRelease(service)
                return ((totalTime - gpuUtil) / totalTime) * 100
            }
        }

        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }

    return nil
}

// MARK: - Thermal

func getThermalState() -> String {
    // Get thermal pressure via process info
    let thermal = ProcessInfo.processInfo.thermalState
    switch thermal {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
}

// MARK: - Uptime

func getUptime() -> String {
    var boottime = timeval()
    var size = MemoryLayout<timeval>.size
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

    guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else {
        return "unknown"
    }

    let uptime = Date().timeIntervalSince1970 - Double(boottime.tv_sec)
    let days = Int(uptime) / 86400
    let hours = (Int(uptime) % 86400) / 3600
    let minutes = (Int(uptime) % 3600) / 60

    if days > 0 {
        return "\(days)d \(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}

// MARK: - Formatting

func formatGB(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824.0
    if gb >= 10 {
        return String(format: "%.0fG", gb)
    } else if gb >= 1 {
        return String(format: "%.1fG", gb)
    } else {
        return String(format: "%.2fG", gb)
    }
}

func formatPercent(_ value: Double) -> String {
    return String(format: "%.0f%%", value)
}

func pressureColor(_ pressure: String) -> String {
    switch pressure {
    case "normal", "nominal": return "green"
    case "warn", "fair": return "yellow"
    case "serious": return "orange"
    case "critical": return "red"
    default: return "white"
    }
}

func cpuColor(_ usage: Double) -> String {
    if usage < 50 { return "green" }
    if usage < 80 { return "yellow" }
    return "red"
}

// MARK: - Main

guard let mem = getMemoryStats() else {
    print("ERR")
    exit(1)
}

let swap = getSwapStats()
let pressure = getMemoryPressure()
let cpu = getCPUUsage()
let gpu = getGPUUsage()
let load = getLoadAverage()
let thermal = getThermalState()
let uptime = getUptime()
let sysInfo = getSystemInfo()

// Menu bar line
let ramUsed = formatGB(mem.used)
let swapUsed = swap.map { formatGB($0.used) } ?? "0G"
print("\(ramUsed)/\(swapUsed)")

// Dropdown
print("---")

// System info header
print("\(sysInfo.chip) | color=gray size=12")
print("\(sysInfo.cores) cores, \(sysInfo.memory) RAM | color=gray size=11")
print("Uptime: \(uptime) | color=gray size=11")
print("---")

// CPU
if let c = cpu {
    let cpuTotal = c.total
    print("CPU: \(formatPercent(cpuTotal)) | color=\(cpuColor(cpuTotal))")
    print("--User: \(formatPercent(c.user))")
    print("--System: \(formatPercent(c.system))")
    print("--Idle: \(formatPercent(c.idle))")
}
if let l = load {
    print("--Load: \(String(format: "%.2f", l.0)) \(String(format: "%.2f", l.1)) \(String(format: "%.2f", l.2)) | color=gray size=11")
}

// GPU
if let g = gpu {
    print("GPU: \(formatPercent(g)) | color=\(cpuColor(g))")
} else {
    print("GPU: - | color=gray")
}

// Thermal
let thermalColor = pressureColor(thermal)
print("Thermal: \(thermal.capitalized) | color=\(thermalColor)")

print("---")

// Memory pressure
let pColor = pressureColor(pressure)
print("Memory Pressure: \(pressure.capitalized) | color=\(pColor)")

// RAM details
print("---")
print("RAM (\(formatGB(mem.used)) / \(formatGB(mem.total))) | color=gray")
print("--App Memory: \(formatGB(mem.appMemory))")
print("--Wired: \(formatGB(mem.wired))")
print("--Compressed: \(formatGB(mem.compressed))")
print("--Cached Files: \(formatGB(mem.cachedFiles))")
print("---")
print("--Active: \(formatGB(mem.active)) | color=gray size=11")
print("--Inactive: \(formatGB(mem.inactive)) | color=gray size=11")
print("--Purgeable: \(formatGB(mem.purgeable)) | color=gray size=11")
print("--Speculative: \(formatGB(mem.speculative)) | color=gray size=11")
print("--Free: \(formatGB(mem.free)) | color=gray size=11")

// Swap details
print("---")
if let s = swap {
    let swapColor = s.used > 0 ? "yellow" : "green"
    print("Swap: \(formatGB(s.used)) / \(formatGB(s.total)) | color=\(swapColor)")
} else {
    print("Swap: None | color=green")
}

// Actions
print("---")
print("Open Activity Monitor | bash=open param1=-a param2='Activity Monitor' terminal=false")
print("Refresh | refresh=true")
