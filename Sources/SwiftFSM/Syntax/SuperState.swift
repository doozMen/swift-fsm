import Foundation

public struct SuperState {
    var nodes: [any Node<DefaultIO>]
    var onEntry: [FSMSyncAction]
    var onExit: [FSMSyncAction]

    public init(
        adopts superState: SuperState,
        _ andSuperStates: SuperState...,
        onEntry: [FSMSyncAction] = [],
        onExit: [FSMSyncAction] = []
    ) {
        self.init(superStates: [superState] + andSuperStates, 
                  onEntry: onEntry,
                  onExit: onExit)
    }

    public init(
        adopts superStates: SuperState...,
        onEntry: [FSMSyncAction] = [],
        onExit: [FSMSyncAction] = [],
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) {
        self.init(nodes: block().nodes.withGroupID(),
                  superStates: superStates,
                  onEntry: onEntry,
                  onExit: onExit)
    }

    private init(
        nodes: [any Node<DefaultIO>] = [],
        superStates: [SuperState],
        onEntry: [FSMSyncAction],
        onExit: [FSMSyncAction]
    ) {
        self.nodes = superStates.map(\.nodes).flattened + nodes
        self.onEntry = superStates.map(\.onEntry).flattened + onEntry
        self.onExit = superStates.map(\.onExit).flattened + onExit
    }
}

extension [any Node<DefaultIO>] {
    func withGroupID() -> Self {
        let groupID = UUID()
        (self as? [OverridableNode])?.forEach { $0.groupID = groupID }
        return self
    }
}
