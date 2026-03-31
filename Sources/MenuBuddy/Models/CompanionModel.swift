import Foundation
import IOKit

// MARK: - Mulberry32 PRNG (ported from TypeScript buddy source)

struct Mulberry32 {
    private var state: UInt32

    init(seed: UInt32) {
        self.state = seed
    }

    mutating func next() -> Double {
        state &+= 0x6d2b79f5
        var t = UInt64(state ^ (state >> 15)) &* UInt64(1 | state)
        t = UInt64(UInt32(truncatingIfNeeded: t) ^ (UInt32(truncatingIfNeeded: t) >> 7)) &* UInt64(61 | UInt32(truncatingIfNeeded: t))
        let result = UInt32(truncatingIfNeeded: t ^ (t >> 14))
        return Double(result) / 4294967296.0
    }
}

// MARK: - FNV-1a 32-bit hash (matches TypeScript fallback)

func fnv1a32(_ s: String) -> UInt32 {
    var h: UInt32 = 2166136261
    for byte in s.utf8 {
        h ^= UInt32(byte)
        h = h &* 16777619
    }
    return h
}

// MARK: - Companion Generation

private let salt = "friend-2026-401"

func rollCompanion(userId: String) -> CompanionBones {
    let key = userId + salt
    let seed = fnv1a32(key)
    var rng = Mulberry32(seed: seed)

    let rarity = rollRarity(&rng)
    let species = pickRandom(&rng, from: Species.allCases)
    let eye = pickRandom(&rng, from: Eye.allCases)
    let hat: Hat = rarity == .common ? .none : pickRandom(&rng, from: Hat.allCases)
    let shiny = rng.next() < 0.01
    let stats = rollStats(&rng, rarity: rarity)

    return CompanionBones(
        rarity: rarity,
        species: species,
        eye: eye,
        hat: hat,
        shiny: shiny,
        stats: stats
    )
}

private func pickRandom<T>(_ rng: inout Mulberry32, from array: [T]) -> T {
    let index = Int(rng.next() * Double(array.count))
    return array[min(index, array.count - 1)]
}

private func rollRarity(_ rng: inout Mulberry32) -> Rarity {
    let total = Rarity.allCases.reduce(0) { $0 + $1.weight }
    var roll = rng.next() * Double(total)
    for rarity in Rarity.allCases {
        roll -= Double(rarity.weight)
        if roll < 0 { return rarity }
    }
    return .common
}

private func rollStats(_ rng: inout Mulberry32, rarity: Rarity) -> [StatName: Int] {
    let floor = rarity.statFloor
    let peak = pickRandom(&rng, from: StatName.allCases)
    var dump = pickRandom(&rng, from: StatName.allCases)
    while dump == peak {
        dump = pickRandom(&rng, from: StatName.allCases)
    }

    var stats: [StatName: Int] = [:]
    for name in StatName.allCases {
        if name == peak {
            stats[name] = min(100, floor + 50 + Int(rng.next() * 30))
        } else if name == dump {
            stats[name] = max(1, floor - 10 + Int(rng.next() * 15))
        } else {
            stats[name] = floor + Int(rng.next() * 40)
        }
    }
    return stats
}

// MARK: - Machine ID

func getMachineId() -> String {
    let platformExpert = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("IOPlatformExpertDevice")
    )
    defer { IOObjectRelease(platformExpert) }

    if platformExpert != 0,
       let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
           platformExpert,
           "IOPlatformUUID" as CFString,
           kCFAllocatorDefault,
           0
       ) {
        return (serialNumberAsCFString.takeRetainedValue() as? String) ?? "anon"
    }
    return "anon"
}
