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
    var previousEpochStartShard: UInt64
    let currentEpochStartShard: UInt64
    var previousCalculationEpoch: UInt64
    let currentCalculationEpoch: UInt64
    var previousEpochSeed: Data
    var currentEpochSeed: Data

//    @todo will be defined in 1.0
//    let custodyChallenges: [CustodyChallenges]

    var previousJustifiedEpoch: UInt64
    var justifiedEpoch: UInt64
    var justificationBitfield: UInt64
    var finalizedEpoch: UInt64

    var latestCrosslinks: [Crosslink]
    var latestBlockRoots: [Data]
    var latestIndexRoots: [Data]
    var latestPenalizedBalances: [UInt64]
    var latestAttestations: [PendingAttestation]
    var batchedBlockRoots: [Data]

    var latestEth1Data: Eth1Data
    var eth1DataVotes: [Eth1DataVote]
}
