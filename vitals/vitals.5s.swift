#!/usr/bin/env swift

import Foundation
import Darwin

// MARK: - Memory Stats

struct MemoryStats {
    let pageSize: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let total: UInt64

    var used: UInt64 {
        active + wired + compressed
    }

    var available: UInt64 {
        free + inactive
    }
}

struct SwapStats {
    let used: UInt64
    let total: UInt64
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

    // Get total physical memory
    var totalMem: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)

    return MemoryStats(
        pageSize: pageSize,
        free: UInt64(stats.free_count) * pageSize,
        active: UInt64(stats.active_count) * pageSize,
        inactive: UInt64(stats.inactive_count) * pageSize,
        wired: UInt64(stats.wire_count) * pageSize,
        compressed: UInt64(stats.compressor_page_count) * pageSize,
        total: totalMem
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
    // Use sysctl to get memory pressure level
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

func pressureColor(_ pressure: String) -> String {
    switch pressure {
    case "normal": return "green"
    case "warn": return "yellow"
    case "critical": return "red"
    default: return "white"
    }
}

func pressureEmoji(_ pressure: String) -> String {
    switch pressure {
    case "normal": return ":large_green_circle:"
    case "warn": return ":large_yellow_circle:"
    case "critical": return ":red_circle:"
    default: return ""
    }
}

// MARK: - Main

guard let mem = getMemoryStats() else {
    print("ERR")
    exit(1)
}

let swap = getSwapStats()
let pressure = getMemoryPressure()

// Menu bar line
let ramUsed = formatGB(mem.used)
let swapUsed = swap.map { formatGB($0.used) } ?? "0G"
print("\(ramUsed)/\(swapUsed)")

// Dropdown
print("---")

// Memory pressure
let pColor = pressureColor(pressure)
print("Memory Pressure: \(pressure.capitalized) | color=\(pColor)")
print("---")

// RAM details
print("RAM | color=gray")
print("--Used: \(formatGB(mem.used))")
print("--Available: \(formatGB(mem.available))")
print("--Compressed: \(formatGB(mem.compressed))")
print("--Wired: \(formatGB(mem.wired))")
print("--Active: \(formatGB(mem.active))")
print("--Inactive: \(formatGB(mem.inactive))")
print("--Free: \(formatGB(mem.free))")
print("--Total: \(formatGB(mem.total))")

// Swap details
print("---")
print("Swap | color=gray")
if let s = swap {
    print("--Used: \(formatGB(s.used))")
    print("--Total: \(formatGB(s.total))")
} else {
    print("--Not available")
}

// Actions
print("---")
print("Open Activity Monitor | bash=open param1=-a param2='Activity Monitor' terminal=false")
print("Refresh | refresh=true")
