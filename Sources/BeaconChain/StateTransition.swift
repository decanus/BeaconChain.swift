import Foundation

class StateTransition {

    static func processBlock(state: BeaconState, block: Block) -> BeaconState {
        assert(state.slot == block.slot) // @todo not sure if assert or other error handling

        // @todo Proposer signature
        // @todo RANDAO
        // @todo Eth1 data
        for eth1VoteData in state.eth1DataVotes {
            if eth1VoteData.eth1Data == block.eth
        }

        proposerSlashings(state: state, block: block)
        casperSlashings(state: state, block: block)
        // @todo Attestations
        // @todo Deposits
        exits(state: state, block: block)

        return state
    }

    static func proposerSlashings(state: BeaconState, block: Block) {
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

            BeaconChain.penalizeValidator(state: state, index: slashing.proposerIndex)
        }
    }

    static func casperSlashings(state: BeaconState, block: Block) {
        assert(block.body.casperSlashings.count <= MAX_CASPER_SLASHINGS)

        for slashing in block.body.casperSlashings {
            // @todo
        }
    }

    static func exits(state: BeaconState, block: Block) {
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

            BeaconChain.initiateValidatorExit(state: state, index: exit.validatorIndex)
        }
    }
}
