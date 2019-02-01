import Foundation

struct BeaconState {
    var slot: UInt64
    let genesisTime: UInt64
    let fork: Fork

    var validatorRegistry: [Validator]
    var validatorBalances: [UInt64]
    let validatorRegistryUpdateEpoch: UInt64
    var validatorRegistryExitCount: UInt64

    var latestRandaoMixes: [Data]
    let latestVdfOutputs: [Data]
    let previousEpochStartShard: UInt64
    let currentEpochStartShard: UInt64
    let previousCalculationEpoch: UInt64
    let currentCalculationEpoch: UInt64
    let previousEpochSeed: Data
    var currentEpochSeed: Data

//    @todo will be defined in 1.0
//    let custodyChallenges: [CustodyChallenges]

    let previousJustifiedEpoch: UInt64
    let justifiedEpoch: UInt64
    let justificationBitfield: UInt64
    let finalizedEpoch: UInt64

    let latestCrosslinks: [Crosslink]
    var latestBlockRoots: [Data]
    var latestIndexRoots: [Data]
    var latestPenalizedBalances: [UInt64]
    let latestAttestations: [PendingAttestation]
    var batchedBlockRoots: [Data]

    let latestEth1Data: Eth1Data
    var eth1DataVotes: [Eth1DataVote]
}
