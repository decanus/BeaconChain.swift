import Foundation

struct AttestationData: Equatable {
    let slot: SlotNumber
    let shard: UInt64
    let beaconBlockRoot: Data
    let epochBoundaryRoot: Data
    let shardBlockRoot: Data
    let latestCrosslink: Crosslink
    let justifiedEpoch: EpochNumber
    let justifiedBlockRoot: Data
}
