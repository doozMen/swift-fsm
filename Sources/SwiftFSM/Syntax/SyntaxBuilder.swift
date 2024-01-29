import Foundation

public protocol SyntaxBuilder {
    associatedtype State: Hashable
    associatedtype Event: Hashable
}

public extension SyntaxBuilder {
    func define(
        _ state: State,
        adopts superState: SuperState,
        _ andSuperStates: SuperState...,
        onEntry: [FSMSyncAction] = [],
        onExit: [FSMSyncAction] = [],
        file: String = #file,
        line: Int = #line
    ) -> Syntax.Define<State> {
        .init(state,
              adopts: [superState] + andSuperStates,
              onEntry: onEntry,
              onExit: onExit,
              elements: [],
              file: file,
              line: line)
    }

    func define(
        _ state: State,
        adopts superStates: SuperState...,
        onEntry: [FSMSyncAction] = [],
        onExit: [FSMSyncAction] = [],
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Syntax.Define<State> {
        .init(state: state,
              adopts: superStates,
              onEntry: onEntry,
              onExit: onExit,
              file: file,
              line: line,
              block)
    }

    func define(
        _ state: State,
        onEntry: [FSMSyncAction] = [],
        onExit: [FSMSyncAction] = [],
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Syntax.Define<State> {
        .init(state: state,
              adopts: [],
              onEntry: onEntry,
              onExit: onExit,
              file: file,
              line: line,
              block)
    }

    func when(
        _ event: Event,
        or otherEvents: Event...,
        file: String = #file,
        line: Int = #line
    ) -> Syntax.When<State, Event> {
        .init([event] + otherEvents, file: file, line: line)
    }

    func when(
        _ event: Event,
        file: String = #file,
        line: Int = #line
    ) -> Syntax.When<State, Event> {
        .init(event, file: file, line: line)
    }

    func when(
        _ event: Event,
        or otherEvents: Event...,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MWTASentence {
        Syntax.When<State, Event>([event] + otherEvents, file: file, line: line)
            .callAsFunction(block)
    }

    func when(
        _ event: Event,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MWTASentence {
        Syntax.When<State, Event>(event, file: file, line: line)
            .callAsFunction(block)
    }

    func when(
        _ event: Event,
        or otherEvents: Event...,
        file: String = #file,
        line: Int = #line,
        @Internal.MABuilder _ block: () -> [MA]
    ) -> Internal.MWASentence {
        Syntax.When<State, Event>([event] + otherEvents, file: file, line: line)
            .callAsFunction(block)
    }

    func when(
        _ event: Event,
        file: String = #file,
        line: Int = #line,
        @Internal.MABuilder _ block: () -> [MA]
    ) -> Internal.MWASentence {
        Syntax.When<State, Event>(event, file: file, line: line)
            .callAsFunction(block)
    }

    func then(
        _ state: State? = nil,
        file: String = #file,
        line: Int = #line
    ) -> Syntax.Then<State, Event> {
        .init(state, file: file, line: line)
    }

    func then(
        _ state: State? = nil,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWTASentence {
        Syntax.Then<State, Event>(state, file: file, line: line)
            .callAsFunction(block)
    }

    func then(
        _ state: State? = nil,
        file: String = #file,
        line: Int = #line,
        @Internal.MABuilder _ block: () -> [MA]
    ) -> Internal.MTASentence {
        Syntax.Then<State, Event>(state, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncAction,
        _ otherActions: FSMSyncAction...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Syntax.Actions<Event>([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncActionWithEvent<Event>,
        _ otherActions: FSMSyncActionWithEvent<Event>...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Syntax.Actions<Event>([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncAction,
        _ otherActions: FSMSyncAction...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Syntax.Actions<Event>([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncActionWithEvent<Event>,
        _ otherActions: FSMSyncActionWithEvent<Event>...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Syntax.Actions([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncAction,
        _ otherActions: FSMSyncAction...,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Syntax.Actions<Event>([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func actions(
        _ action: @escaping FSMSyncActionWithEvent<Event>,
        _ otherActions: FSMSyncActionWithEvent<Event>...,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Syntax.Actions([action] + otherActions, file: file, line: line)
            .callAsFunction(block)
    }

    func override(
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> [MWTA] {
        Syntax.Override().callAsFunction(block)
    }
}

public protocol ExpandedSyntaxBuilder: SyntaxBuilder { }

public extension ExpandedSyntaxBuilder {
    typealias Matching = Syntax.Expanded.Matching
    typealias Condition = Syntax.Expanded.Condition

    func matching<P: Predicate>(
        _ predicate: P,
        file: String = #file,
        line: Int = #line
    ) -> Matching<State, Event> {
        .init(predicate, file: file, line: line)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        file: String = #file,
        line: Int = #line
    ) -> Matching<State, Event> {
        .init(predicate, or: or, and: [], file: file, line: line)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        and: P...,
        file: String = #file,
        line: Int = #line
    ) -> Matching<State, Event> {
        .init(predicate, or: [], and: and, file: file, line: line)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        and: any Predicate...,
        file: String = #file,
        line: Int = #line
    ) -> Matching<State, Event> {
        .init(predicate, or: or, and: and, file: file, line: line)
    }

    func condition(
        _ condition: @escaping () -> Bool,
        file: String = #file,
        line: Int = #line
    ) -> Condition<State, Event> {
        .init(condition, file: file, line: line)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Matching<State, Event>(predicate, file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Matching<State, Event>(predicate, or: or, and: [], file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        and: any Predicate...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Matching<State, Event>(predicate, or: or, and: and, file: file, line: line)
            .callAsFunction(block)
    }

    func condition(
        _ condition: @escaping () -> Bool,
        file: String = #file,
        line: Int = #line,
        @Internal.MWTABuilder _ block: () -> [MWTA]
    ) -> Internal.MWTASentence {
        Condition<State, Event>(condition, file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Matching<State, Event>(predicate, file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Matching<State, Event>(predicate, or: or, and: [], file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        and: any Predicate...,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Matching<State, Event>(predicate, or: or, and: and, file: file, line: line)
            .callAsFunction(block)
    }

    func condition(
        _ condition: @escaping () -> Bool,
        file: String = #file,
        line: Int = #line,
        @Internal.MWABuilder _ block: () -> [MWA]
    ) -> Internal.MWASentence {
        Condition<State, Event>(condition, file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Matching<State, Event>(predicate, file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Matching<State, Event>(predicate, or: or, and: [], file: file, line: line)
            .callAsFunction(block)
    }

    func matching<P: Predicate>(
        _ predicate: P,
        or: P...,
        and: any Predicate...,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Matching<State, Event>(predicate, or: or, and: and, file: file, line: line)
            .callAsFunction(block)
    }

    func condition(
        _ condition: @escaping () -> Bool,
        file: String = #file,
        line: Int = #line,
        @Internal.MTABuilder _ block: () -> [MTA]
    ) -> Internal.MTASentence {
        Condition<State, Event>(condition, file: file, line: line)
            .callAsFunction(block)
    }
}
