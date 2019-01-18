import Foundation

class StateTransition {

    static func processSlot(state: inout BeaconState, previousBlockRoot: Data) {
        state.slot += 1
        state.validatorRegistry[BeaconChain.getBeaconProposerIndex(state: state, slot: state.slot)].randaoLayers += 1
        state.latestRandaoMixes[state.slot % LATEST_RANDAO_MIXES_LENGTH] = state.latestRandaoMixes[(state.slot - 1) % LATEST_RANDAO_MIXES_LENGTH]

        state.latestBlockRoots[(state.slot - 1) % LATEST_BLOCK_ROOTS_LENGTH] = previousBlockRoot
        if state.slot % LATEST_BLOCK_ROOTS_LENGTH == 0 {
            state.batchedBlockRoots.append(BeaconChain.merkleRoot(values: state.latestBlockRoots))
        }
    }
}

extension StateTransition {

    static func processBlock(state: inout BeaconState, block: Block) {
        assert(state.slot == block.slot) // @todo not sure if assert or other error handling

        // @todo Proposer signature
        // @todo RANDAO
        eth1Data(state: &state, block: block)
        proposerSlashings(state: &state, block: block)
        casperSlashings(state: &state, block: block)
        // @todo Attestations
        // @todo Deposits
        exits(state: &state, block: block)
    }

    private static func eth1Data(state: inout BeaconState, block: Block) {
        for (i, eth1VoteData) in state.eth1DataVotes.enumerated() {
            if eth1VoteData.eth1Data == block.eth1Data { // @todo make equatable
                state.eth1DataVotes[i].voteCount += 1
            } else {
                state.eth1DataVotes.append(Eth1DataVote(eth1Data: block.eth1Data, voteCount: 1))
            }
        }
    }

    private static func proposerSlashings(state: inout BeaconState, block: Block) {
        for slashing in block.body.proposerSlashings {
            assert(slashing.proposalData1.slot == slashing.proposalData2.slot) // @todo not sure if asserts
            assert(slashing.proposalData1.shard == slashing.proposalData2.shard) // @todo not sure if asserts
            assert(slashing.proposalData1.blockRoot != slashing.proposalData2.blockRoot) // @todo not sure if asserts

            let proposer = state.validatorRegistry[slashing.proposerIndex]
            assert(proposer.penalizedSlot > state.slot) // @todo not sure if asserts

            assert(
                BLS.verify(
                    pubkey: proposer.pubkey,
                    message: BeaconChain.hashTreeRoot(data: slashing.proposalData1),
                    signature: slashing.proposalSignature1,
                    domain: BeaconChain.getDomain(data: state.fork, slot: slashing.proposalData1.slot, domainType: DOMAIN_PROPOSAL)
                )
            )
            assert(
                BLS.verify(
                    pubkey: proposer.pubkey,
                    message: BeaconChain.hashTreeRoot(data: slashing.proposalData2),
                    signature: slashing.proposalSignature2,
                    domain: BeaconChain.getDomain(data: state.fork, slot: slashing.proposalData2.slot, domainType: DOMAIN_PROPOSAL)
                )
            )

            BeaconChain.penalizeValidator(state: &state, index: slashing.proposerIndex)
        }
    }

    private static func casperSlashings(state: inout BeaconState, block: Block) {
        assert(block.body.casperSlashings.count <= MAX_CASPER_SLASHINGS)

        for slashing in block.body.casperSlashings {
            // @todo
        }
    }

    private static func exits(state: inout BeaconState, block: Block) {
        assert(block.body.exits.count <= MAX_EXITS)

        for exit in block.body.exits {
            let validator = state.validatorRegistry[exit.validatorIndex]
            assert(validator.exitSlot > state.slot + ENTRY_EXIT_DELAY)
            assert(state.slot >= exit.slot)
            assert(
                BLS.verify(
                    pubkey: validator.pubkey,
                    message: ZERO_HASH,
                    signature: exit.signature,
                    domain: BeaconChain.getDomain(data: state.fork, slot: state.slot, domainType: DOMAIN_EXIT)
                )
            )

            BeaconChain.initiateValidatorExit(state: &state, index: exit.validatorIndex)
        }
    }
}

extension StateTransition {

    func processEpoch(state: inout BeaconState) {
        assert(state.slot % EPOCH_LENGTH == 1)
        let activeValidators = BeaconChain.getActiveValidatorIndices(validators: state.validatorRegistry, slot: state.slot)
        let totalBalance = activeValidators.map({
            (i: Int) -> Int in
            return BeaconChain.getEffectiveBalance(state: state, index: i)
        }).reduce(0, +)

        let currentEpochAttestations = state.latestAttestations.filter({
            state.slot - EPOCH_LENGTH <= $0.data.slot && $0.data.slot < state.slot
        })

        let currentEpochBoundryAttestations = currentEpochAttestations.filter({
            $0.data.epochBoundryRoot == BeaconChain.getBlockRoot(state: state, slot: state.slot - EPOCH_LENGTH)
                && $0.data.justifiedSlot == state.justifiedSlot
        })

        var currentEpochBoundaryAttesterIndices = Set<Int>()
        for attestation in currentEpochAttestations {
            currentEpochBoundaryAttesterIndices = currentEpochBoundaryAttesterIndices.union(
                BeaconChain.getAttestationParticipants(
                    state: state,
                    data: attestation.data,
                    aggregationBitfield: attestation.aggregationBitfield
                )
            )
        }

        let currentEpochBoundaryAttestingBalance = currentEpochBoundaryAttesterIndices.map({
            (i: Int) -> Int in
            return BeaconChain.getEffectiveBalance(state: state, index: i)
        }).reduce(0, +)

        let previousEpochAttestations = state.latestAttestations.filter({
            state.slot - (2 * EPOCH_LENGTH) <= $0.data.slot && $0.data.slot < state.slot - EPOCH_LENGTH
        })

        var previousEpochAttesterIndices = Set<Int>()
        for attestation in previousEpochAttestations {
            previousEpochAttesterIndices = previousEpochAttesterIndices.union(
                BeaconChain.getAttestationParticipants(
                    state: state,
                    data: attestation.data,
                    aggregationBitfield: attestation.aggregationBitfield
                )
            )
        }

        let previousEpochJustifiedAttestations = (currentEpochBoundryAttestations + previousEpochAttestations).filter({
            $0.data.justifiedSlot == state.justifiedSlot
        })

        var previousEpochJustifiedAttesterIndices = Set<Int>()
        for attestation in previousEpochAttestations {
            previousEpochJustifiedAttesterIndices = previousEpochJustifiedAttesterIndices.union(
                BeaconChain.getAttestationParticipants(
                    state: state,
                    data: attestation.data,
                    aggregationBitfield: attestation.aggregationBitfield
                )
            )
        }

        let previousEpochJustifiedAttestingBalance = previousEpochJustifiedAttesterIndices.map({
            (i: Int) -> Int in
            return BeaconChain.getEffectiveBalance(state: state, index: i)
        }).reduce(0, +)

        let previousEpochBoundaryAttestations = previousEpochJustifiedAttestations.filter({
            $0.data.epochBoundryRoot == BeaconChain.getBlockRoot(state: state, slot: state.slot - 2 * EPOCH_LENGTH)
        })

        var previousEpochBoundaryAttesterIndices = Set<Int>()
        for attestation in previousEpochBoundaryAttestations {
            previousEpochBoundaryAttesterIndices = previousEpochBoundaryAttesterIndices.union(
                BeaconChain.getAttestationParticipants(
                    state: state,
                    data: attestation.data,
                    aggregationBitfield: attestation.aggregationBitfield
                )
            )
        }

        let previousEpochBoundaryAttestingBalance = previousEpochJustifiedAttesterIndices.map({
            (i: Int) -> Int in
            return BeaconChain.getEffectiveBalance(state: state, index: i)
        }).reduce(0, +)

        let previousEpochHeadAttestations = previousEpochAttestations.filter({
            $0.data.beaconBlockRoot == BeaconChain.getBlockRoot(state: state, slot: state.slot)
        })

        var previousEpochHeadAttesterIndices = Set<Int>()
        for attestation in previousEpochHeadAttestations {
            previousEpochHeadAttesterIndices = previousEpochHeadAttesterIndices.union(
                BeaconChain.getAttestationParticipants(
                    state: state,
                    data: attestation.data,
                    aggregationBitfield: attestation.aggregationBitfield
                )
            )
        }

        let previousEpochHeadAttestingBalance = previousEpochHeadAttesterIndices.map({
            (i: Int) -> Int in
            return BeaconChain.getEffectiveBalance(state: state, index: i)
        }).reduce(0, +)

        eth1Data(state: &state)
        // @todo Justification
        // @todo Crosslinks
        // @todo Rewards and penalties
        // @todo Ejections
        // @todo Validator registry
        // @todo Final updates

    }

    private func eth1Data(state: inout BeaconState) {
        if (state.slot % ETH1_DATA_VOTING_PERIOD != 0) {
            return
        }

        for eth1DataVote in state.eth1DataVotes {
            if eth1DataVote.voteCount * 2 > ETH1_DATA_VOTING_PERIOD {
                state.latestEth1Data = eth1DataVote.eth1Data
            }
        }

        state.eth1DataVotes = [Eth1DataVote]()
    }

    private func justification(
        state: inout BeaconState,
        totalBalance: Int,
        previousEpochBoundaryAttestingBalance: Int,
        currentEpochBoundaryAttestingBalance: Int
    )
    {
        state.previousJustifiedSlot = state.justifiedSlot
        state.justificationBitfield = (state.justificationBitfield * 2) % 2^64

        if 3 * previousEpochBoundaryAttestingBalance >= 2 * totalBalance {
            state.justificationBitfield |= 2
            state.justifiedSlot = state.slot - 2 * EPOCH_LENGTH
        }

        if 3 * currentEpochBoundaryAttestingBalance >= 2 * totalBalance {
            state.justificationBitfield |= 1
            state.justifiedSlot = state.slot - 1 * EPOCH_LENGTH
        }

        if (state.previousJustifiedSlot == state.slot - 2 * EPOCH_LENGTH && state.justificationBitfield % 4 == 3) ||
            (state.previousJustifiedSlot == state.slot - 3 * EPOCH_LENGTH && state.justificationBitfield % 8 == 7) ||
            (state.previousJustifiedSlot == state.slot - 4 * EPOCH_LENGTH && [15, 14].contains(state.justificationBitfield % 16))
        {
            state.finalizedSlot = state.previousJustifiedSlot
        }
    }

}
