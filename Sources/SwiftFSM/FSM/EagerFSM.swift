import Foundation

class EagerFSM<State: Hashable, Event: Hashable>: BaseFSM<State, Event>, FSMProtocol {
    func makeMatchResolvingNode(rest: [any Node<IntermediateIO>]) -> any MatchResolvingNode {
        EagerMatchResolvingNode(rest: rest)
    }

    @MainActor
    func handleEvent(_ event: Event, predicates: [any Predicate]) throws {
        try handleResult(_handleEvent(event, predicates: predicates),
                     for: event,
                     with: predicates)
    }

    @MainActor
    func handleEventAsync(_ event: Event, predicates: [any Predicate]) async {
        handleResult(await _handleEventAsync(event, predicates: predicates),
                     for: event,
                     with: predicates)
    }

    @MainActor
    private func handleResult(_ result: TransitionStatus<Event>, for event: Event, with predicates: [any Predicate]) {
        switch result {
        case let .notExecuted(transition):
            logTransitionNotExecuted(transition)
        case .notFound:
            logTransitionNotFound(event, predicates)
        case .executed:
            return
        }
    }
}
