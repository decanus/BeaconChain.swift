import BeaconChain

class MockStore: Store {

    var ancestor: BeaconBlock!

    func parent(_ block: BeaconBlock) -> BeaconBlock {
        return block
    }

    func children(_ block: BeaconBlock) -> [BeaconBlock] {
        return [block]
    }

    func latestAttestation(validator: ValidatorIndex) -> Attestation {
        fatalError()
    }

    func latestAttestationTarget(validator: ValidatorIndex) -> BeaconBlock {
        fatalError()
    }
}
