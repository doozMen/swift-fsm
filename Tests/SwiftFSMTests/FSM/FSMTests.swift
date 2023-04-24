import Foundation
import XCTest
@testable import SwiftFSM

class FSMTestsBase<State: Hashable, Event: Hashable>: XCTestCase, ExpandedSyntaxBuilder {
    typealias StateType = State
    typealias EventType = Event
    
    var fsm: (any FSMProtocol<StateType, EventType>)!
    
    override func setUp() {
        fsm = makeSUT(initialState: initialState)
    }
    
    var initialState: State {
        fatalError("subclasses must implement")
    }
    
    func makeSUT<State: Hashable, Event: Hashable>(
        initialState: State
    ) -> any FSMProtocol<State, Event> {
        fatalError("subclasses must implement")
    }
}

class LazyFSMTests: FSMTests {
    override func setUpWithError() throws {
        throw XCTSkip("not ready yet")
    }
    
    override func makeSUT<State: Hashable, Event: Hashable>(
        initialState: State
    ) -> any FSMProtocol<State, Event> {
        LazyFSM<State, Event>(initialState: initialState)
    }
}

class FSMTests: FSMTestsBase<Int, Double> {
    override var initialState: Int { 1 }
    
    override func makeSUT<State: Hashable, Event: Hashable>(
        initialState: State
    ) -> any FSMProtocol<State, Event> {
        FSM<State, Event>(initialState: initialState)
    }
    
    func assertThrowsError<T: Error>(
        _ type: T.Type,
        count: Int = 1,
        line: UInt = #line,
        block: () throws -> (),
        completion: (T?) -> () = { _ in }
    ) {
        XCTAssertThrowsError(try block(), line: line) {
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(count, errors?.count, line: line)
            XCTAssertTrue(errors?.first is T, String(describing: errors), line: line)
            completion(errors?.first as? T)
        }
    }
    
    func testSuccessfulInit() {
        XCTAssertEqual(1, fsm.state)
    }
    
    func testBuildEmptyTable() {
        assertThrowsError(EmptyTableError.self) {
            try fsm.buildTable { }
        }
    }

    func testThrowsErrorsFromNodes() {
        assertThrowsError(EmptyBuilderError.self) {
            try fsm.buildTable { define(1) { } }
        }
    }

    func testThrowsNSObjectError()  {
        let fsm1: any FSMProtocol<NSObject, Int> = makeSUT(initialState: NSObject())
        let fsm2: any FSMProtocol<Int, NSObject> = makeSUT(initialState: 1)

        assertThrowsError(NSObjectError.self) {
            try fsm1.buildTable {
                Syntax.Define(NSObject()) { Syntax.When(1) | Syntax.Then(NSObject()) }
            }
        }

        assertThrowsError(NSObjectError.self) {
            try fsm2.buildTable {
                Syntax.Define(1) { Syntax.When(NSObject()) | Syntax.Then(2) }
            }
        }
    }

    func testValidTableDoesNotThrow() {
        XCTAssertNoThrow(
            try fsm.buildTable { define(1) { when(1.1) | then(2) } }
        )
    }

    func testCallingBuildTableTwiceThrows() throws {
        try fsm.buildTable { define(1) { when(1.1) | then(2) } }
        assertThrowsError(TableAlreadyBuiltError.self) {
            try fsm.buildTable(file: "f", line: 1) { define(1) { when(1.1) | then(2) } }
        } completion: {
            XCTAssertEqual("f", $0?.file)
            XCTAssertEqual(1, $0?.line)
        }
    }

    var actionsOutput = ""
    func assertHandleEvent(
        _ event: EventType,
        predicates: any Predicate...,
        state: StateType,
        output: String,
        line: UInt = #line
    ) {
        fsm.handleEvent(event, predicates: predicates)
        XCTAssertEqual(state, fsm.state, line: line)
        XCTAssertEqual(output, actionsOutput, line: line)

        actionsOutput = ""
        fsm.state = 1
    }

    func pass() {
        actionsOutput = "pass"
    }

    func testHandleEventWithoutPredicate() throws {
        try fsm.buildTable {
            define(1) { when(1.1) | then(2) | pass }
        }

        assertHandleEvent(1.1, state: 2, output: "pass")
        assertHandleEvent(1.2, state: 1, output: "")
    }

    func testHandleEventWithSinglePredicate() throws {
        try fsm.buildTable {
            define(1) { matching(P.a) | when(1.1) | then(2) | pass }
            define(1) { matching(P.b) | when(1.1) | then(3) | pass }
        }

        assertHandleEvent(1.1, predicates: P.a, state: 2, output: "pass")
        assertHandleEvent(1.1, predicates: P.b, state: 3, output: "pass")
    }

    func testHandlEventWithMultiplePredicates() throws {
        try fsm.buildTable {
            define(1) { matching(P.a, or: P.b)  | when(1.1) | then(2) | pass }
            define(1) { matching(Q.a, and: R.a) | when(1.1) | then(3) | pass }
        }

        assertHandleEvent(1.1, predicates: P.a, Q.b, R.a, state: 2, output: "pass")
        assertHandleEvent(1.1, predicates: P.a, Q.a, R.a, state: 3, output: "pass")
    }

    func testHandlEventWithCondition() throws {
        try fsm.buildTable {
            define(1) { condition { false } | when(1.1) | then(2) | pass }
            define(2) { condition { true  } | when(1.1) | then(3) | pass }
        }

        assertHandleEvent(1.1, state: 1, output: "")
        fsm.state = 2
        assertHandleEvent(1.1, state: 3, output: "pass")
    }
}

enum TurnstileState: String, CustomStringConvertible {
    case locked, unlocked, alarming
    var description: String { rawValue  }
}

enum TurnstileEvent: String, CustomStringConvertible {
    case reset, coin, pass
    var description: String { rawValue }
}

class FSMIntegrationTests: FSMTestsBase<TurnstileState, TurnstileEvent> {
    var actions = [String]()
    var actual = [String]()
    
    func alarmOn()  { actions.append("alarmOn")  }
    func alarmOff() { actions.append("alarmOff") }
    func lock()     { actions.append("lock")     }
    func unlock()   { actions.append("unlock")   }
    func thankyou() { actions.append("thankyou") }
    
    override var initialState: TurnstileState { .locked }
    
    override func makeSUT<State: Hashable, Event: Hashable>(
        initialState: State
    ) -> any FSMProtocol<State, Event> {
        FSM<State, Event>(initialState: initialState)
    }
}

final class FSMIntegrationTests_Turnstile: FSMIntegrationTests {
    func assertEventAction(_ e: EventType, _ a: String, line: UInt = #line) {
        assertEventAction(e, a.isEmpty ? [] : [a], line: line)
    }
    
    func assertEventAction(_ e: EventType, _ a: [String], line: UInt = #line) {
        actual += a
        fsm.handleEvent(e)
        XCTAssertEqual(actions, actual, line: line)
    }
    
    func assertTurnstile() {
        assertEventAction(.coin,  "unlock")
        assertEventAction(.pass,  "lock")
        assertEventAction(.pass,  "alarmOn")
        assertEventAction(.reset, ["alarmOff", "lock"])
        assertEventAction(.coin,  "unlock")
        assertEventAction(.coin,  "thankyou")
        assertEventAction(.coin,  "thankyou")
        assertEventAction(.reset, "lock")
    }
    
    func testTurnstile() throws {
        try fsm.buildTable {
            let resetable = SuperState {
                when(.reset) | then(.locked)
            }

            define(.locked, adopts: resetable, onEntry: [lock]) {
                when(.coin) | then(.unlocked)
                when(.pass) | then(.alarming)
            }
            
            define(.unlocked, adopts: resetable, onEntry: [unlock]) {
                when(.coin) | then(.unlocked) | thankyou
                when(.pass) | then(.locked)
            }
            
            define(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertTurnstile()
    }
    
    func testConditionTurnstile() throws {
        var bool = false
        
        try fsm.buildTable {
            let resetable = SuperState {
                condition { bool } | when(.reset) | then(.locked)
            }
            
            define(.locked, adopts: resetable, onEntry: [lock]) {
                condition { bool } | when(.coin) | then(.unlocked)
                condition { bool } | when(.pass) | then(.alarming)
            }
            
            define(.unlocked, adopts: resetable, onEntry: [unlock]) {
                condition { bool } | when(.coin) | then(.unlocked) | thankyou
                condition { bool } | when(.pass) | then(.locked)
            }
            
            define(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertEventAction(.coin,  "")
        assertEventAction(.pass,  "")
        assertEventAction(.reset,  "")

        fsm.state = AnyHashable(StateType.unlocked)
        
        assertEventAction(.coin,  "")
        assertEventAction(.pass,  "")
        assertEventAction(.reset,  "")
        
        fsm.state = AnyHashable(StateType.alarming)
        
        assertEventAction(.reset,  "")

        fsm.state = AnyHashable(StateType.locked)
        bool = true
        
        assertTurnstile()
    }
}

final class FSMIntegrationTests_PredicateTurnstile: FSMIntegrationTests {
    enum Enforcement: Predicate { case strong, weak }
    enum Reward: Predicate { case punishing, rewarding }
    
    func idiot() { actions.append("idiot") }
    
    func assertEventAction(_ e: EventType, _ a: String, line: UInt = #line) {
        assertEventAction(e, [a], line: line)
    }
    
    func assertEventAction(_ e: EventType, _ a: [String], line: UInt = #line) {
        if !(a.first?.isEmpty ?? false) {
            actual += a
        }
        fsm.handleEvent(e, predicates: [Enforcement.weak, Reward.punishing])
        XCTAssertEqual(actions, actual, line: line)
    }
    
    func assertTable() {
        assertEventAction(.coin,  "unlock")
        assertEventAction(.pass,  "lock")
        assertEventAction(.pass,  "")
        assertEventAction(.reset, "")
        assertEventAction(.coin,  "unlock")
        assertEventAction(.coin,  "idiot")
        assertEventAction(.coin,  "idiot")
        assertEventAction(.reset, "lock")
    }
    
    func testPredicateTurnstile() throws {
        try fsm.buildTable {
            let resetable = SuperState {
                when(.reset) | then(.locked)
            }
            
            define(.locked, adopts: resetable, onEntry: [lock]) {
                matching(Enforcement.weak)   | when(.pass) | then(.locked)
                matching(Enforcement.strong) | when(.pass) | then(.alarming)
                
                when(.coin) | then(.unlocked)
            }
            
            define(.unlocked, adopts: resetable, onEntry: [unlock]) {
                matching(Reward.rewarding) | when(.coin) | then(.unlocked) | thankyou
                matching(Reward.punishing) | when(.coin) | then(.unlocked) | idiot
                
                when(.pass) | then(.locked)
            }
            
            define(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertTable()
    }
    
    func testDeduplicatedPredicateTurnstile() throws {
        try fsm.buildTable {
            let resetable = SuperState {
                when(.reset) | then(.locked)
            }
            
            define(.locked, adopts: resetable, onEntry: [lock]) {
                when(.pass) {
                    matching(Enforcement.weak)   | then(.locked)
                    matching(Enforcement.strong) | then(.alarming)
                }
                
                when(.coin) | then(.unlocked)
            }
            
            define(.unlocked, adopts: resetable, onEntry: [unlock]) {
                when(.coin) {
                    then(.unlocked) {
                        matching(Reward.rewarding) | thankyou
                        matching(Reward.punishing) | idiot
                    }
                }
                
                when(.pass) | then(.locked)
            }
            
            define(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertTable()
    }
    
    func testTypealiasSyntaxTurnstile() throws {
        typealias State = Syntax.Define<StateType>
        typealias Event = Syntax.When<EventType>
        typealias NextState = Syntax.Then<StateType>
        typealias If = Syntax.Expanded.Matching
        
        try fsm.buildTable {
            let resetable = SuperState {
                Event(.reset) | NextState(.locked)
            }
            
            State(.locked, adopts: resetable, onEntry: [lock]) {
                Event(.pass) {
                    If(Enforcement.weak)   | NextState(.locked)
                    If(Enforcement.strong) | NextState(.alarming)
                }
                
                Event(.coin) | NextState(.unlocked)
            }
            
            State(.unlocked, adopts: resetable, onEntry: [unlock]) {
                NextState(.unlocked) {
                    If(Reward.rewarding) | Event(.coin) | thankyou
                    If(Reward.punishing) | Event(.coin) | idiot
                }
                
                Event(.pass) | NextState(.locked)
            }
            
            State(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertTable()
    }
    
    func testActionsBlockTurnstile() throws {
        try fsm.buildTable {
            let resetable = SuperState {
                when(.reset) | then(.locked)
            }
            
            define(.locked, adopts: resetable, onEntry: [lock]) {
                when(.pass) {
                    matching(Enforcement.weak)   | then(.locked)
                    matching(Enforcement.strong) | then(.alarming)
                }
                
                when(.coin) | then(.unlocked)
            }
            
            define(.unlocked, adopts: resetable, onEntry: [unlock]) {
                then(.unlocked) {
                    actions(thankyou) {
                        matching(Reward.rewarding) | when(.coin)
                    }
                    
                    actions(idiot) {
                        matching(Reward.punishing) | when(.coin)
                    }
                }
                
                when(.pass) | then(.locked)
            }
            
            define(.alarming, adopts: resetable, onEntry: [alarmOn], onExit: [alarmOff])
        }
        
        assertTable()
    }
}

final class FSMIntegrationTests_NestedBlocks: FSMIntegrationTests {
    func testMultiplePredicateBlocks() throws {
        try fsm.buildTable {
            define(.locked) {
                matching(P.a, or: P.b) {
                    matching(Q.a) {
                        matching(R.a, and: S.a) {
                            matching(T.a, and: U.a) {
                                matching(V.a) | when(.coin) | then() | thankyou
                            }
                        }
                    }
                }
            }
        }
        
        fsm.handleEvent(.coin, predicates: P.a, Q.a, R.a, S.a, T.a, U.a, V.a)
        XCTAssertEqual(["thankyou"], actions)
        
        fsm.handleEvent(.coin, predicates: P.b, Q.a, R.a, S.a, T.a, U.a, V.a)
        XCTAssertEqual(["thankyou", "thankyou"], actions)
        
        actions = []
        fsm.handleEvent(.coin, predicates: P.c, Q.a, R.a, S.a, T.a, U.a, V.a)
        XCTAssertEqual([], actions)
    }
    
    func testMultiplActionsBlocks() throws {
        try fsm.buildTable {
            define(.locked) {
                actions(thankyou) {
                    actions(lock) {
                        matching(P.a) | when(.coin) | then(.locked) | unlock
                    }
                }
            }
        }
        
        fsm.handleEvent(.coin, predicates: P.a)
        XCTAssertEqual(["thankyou", "lock", "unlock"], actions)
    }
}

final class FSMIntegrationTests_Errors: FSMIntegrationTests {
    func assertEmptyError(_ e: EmptyBuilderError?,
                     expectedCaller: String,
                     expectedLine: Int,
                     line: UInt = #line
    ) {
        XCTAssertEqual(expectedCaller, e?.caller, line: line)
        XCTAssertEqual("file", e?.file, line: line)
        XCTAssertEqual(expectedLine, e?.line, line: line)
    }
    
    func testEmptyBlockThrowsError() {
        XCTAssertThrowsError (
            try fsm.buildTable {
                define(.locked, file: "file", line: 1 ) { }
            }
        ) {
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(1, errors?.count)
            let error = errors?.first as? EmptyBuilderError
            
            assertEmptyError(error, expectedCaller: "define", expectedLine: 1)
        }
    }
    
    func testEmptyBlocksThrowErrors() {
        XCTAssertThrowsError (
            try fsm.buildTable {
                define(.locked) {
                    matching(P.a, file: "file", line: 1) {}
                    then(.locked, file: "file", line: 2) {}
                    when(.pass,   file: "file", line: 3) {}
                }
            }
        ) {
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(3, errors?.count)
            
            let e1 = errors?(0) as? EmptyBuilderError
            assertEmptyError(e1, expectedCaller: "matching", expectedLine: 1)
            
            let e2 = errors?(1) as? EmptyBuilderError
            assertEmptyError(e2, expectedCaller: "then", expectedLine: 2)
            
            let e3 = errors?(2) as? EmptyBuilderError
            assertEmptyError(e3, expectedCaller: "when", expectedLine: 3)
        }
    }
    
    func testDuplicatesAndClashesThrowErrors() {
        typealias DE = SemanticValidationNode.DuplicatesError
        typealias CE = SemanticValidationNode.ClashError
        
        XCTAssertThrowsError (
            try fsm.buildTable {
                define(.locked, line: 1) {
                    matching(P.a, line: 2) | when(.coin, line: 3) | then(.unlocked, line: 4)
                    matching(P.a, line: 2) | when(.coin, line: 3) | then(.unlocked, line: 4)
                    matching(P.a, line: 2) | when(.coin, line: 3) | then(.locked, line: 4)
                }
            }
        ) {
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(2, errors?.count)
            
            let e1 = errors?.compactMap { $0 as? DE }.first?.duplicates.values
            let e2 = errors?.compactMap { $0 as? CE }.first?.clashes.values

            XCTAssertEqual(1, e1?.count)
            XCTAssertEqual(1, e2?.count)
            
            let duplicates = e1?.first ?? []
            let clashes = e2?.first ?? []
            
            XCTAssertEqual(2, duplicates.count)
            XCTAssertEqual(2, clashes.count)
            
            XCTAssert(
                duplicates.allSatisfy {
                    $0.state.isEqual(AnyTraceable(StateType.locked, file: #file, line: 1)) &&
                    $0.match.isEqual(Match(all: P.a, file: #file, line: 2)) &&
                    $0.event.isEqual(AnyTraceable(EventType.coin, file: #file, line: 3)) &&
                    $0.nextState.isEqual(AnyTraceable(StateType.unlocked, file: #file, line: 4))
                }, "\(duplicates)"
            )
            
            XCTAssert(
                clashes.allSatisfy {
                    $0.state.isEqual(AnyTraceable(StateType.locked, file: #file, line: 1)) &&
                    $0.match.isEqual(Match(all: P.a, file: #file, line: 2)) &&
                    $0.event.isEqual(AnyTraceable(EventType.coin, file: #file, line: 3))
                }, "\(clashes)"
            )
            
            XCTAssert(clashes.contains { $0.nextState.base == AnyHashable(StateType.locked) })
            XCTAssert(clashes.contains { $0.nextState.base == AnyHashable(StateType.unlocked) })
        }
    }
    
    func testImplicitMatchClashesThrowErrors() {
        XCTAssertThrowsError (
            try fsm.buildTable {
                define(.locked, file: "1", line: 1) {
                    matching(P.a, file: "1", line: 1)
                    | when(.coin, file: "1", line: 1)
                    | then(.unlocked, file: "1", line: 1)
                    
                    matching(Q.a, file: "2", line: 2)
                    | when(.coin, file: "2", line: 2)
                    | then(.locked, file: "2", line: 2)
                }
            }
        ) {
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(1, errors?.count)
            
            let error = errors?.first as? EagerMatchResolvingNode.ImplicitClashesError
            let clashes = error?.clashes.values
            XCTAssertEqual(1, clashes?.count)
            
            let clash = clashes?.first
            XCTAssertEqual(2, clash?.count)
            
            XCTAssert(clash?.contains {
                $0.state.isEqual(AnyTraceable(StateType.locked, file: "1", line: 1)) &&
                $0.event.isEqual(AnyTraceable(EventType.coin, file: "1", line: 1)) &&
                $0.match.isEqual(Match(all: P.a, file: "1", line: 1))
            } ?? false, "\(String(describing: clash))")
            
            XCTAssert(clash?.contains {
                $0.state.isEqual(AnyTraceable(StateType.locked, file: "1", line: 1)) &&
                $0.event.isEqual(AnyTraceable(EventType.coin, file: "2", line: 2)) &&
                $0.match.isEqual(Match(all: Q.a, file: "2", line: 2))
            } ?? false, "\(String(describing: clash))")
            
            XCTAssertEqual(AnyHashable(StateType.unlocked), clash?.first?.nextState.base)
            XCTAssertEqual(AnyHashable(StateType.locked), clash?.last?.nextState.base)
        }
    }
    
    func testMatchesThrowErrors() {
        XCTAssertThrowsError (
            try fsm.buildTable {
                define(.locked) {
                    matching(P.a, or: P.a, file: "1", line: 1)  | when(.coin) | then(.unlocked)
                    matching(P.a, and: P.a, file: "2", line: 2) | when(.coin) | then(.locked)
                }
            }
        ) {
            func assertError(
                _ e: MatchError?,
                expectedFile: String,
                expectedLine: Int,
                line: UInt = #line
            ) {
                XCTAssertEqual([expectedFile], e?.files, line: line)
                XCTAssertEqual([expectedLine], e?.lines, line: line)
                XCTAssert(e?.description.contains("P.a, P.a") ?? false, line: line)
            }
            
            let errors = ($0 as? SwiftFSMError)?.errors
            XCTAssertEqual(2, errors?.count)
            
            assertError(errors?.first as? MatchError, expectedFile: "1", expectedLine: 1)
            assertError(errors?.last as? MatchError, expectedFile: "2", expectedLine: 2)
        }
    }
}

private extension Match {
    func isEqual(_ other: Match) -> Bool {
        self == other && file == other.file && line == other.line
    }
}

private extension AnyTraceable {
    func isEqual(_ other: AnyTraceable) -> Bool {
        self == other && file == other.file && line == other.line
    }
}

extension Int: Predicate {
    public static var allCases: [Int] { [] }
}

extension Double: Predicate {
    public static var allCases: [Double] { [] }
}

extension Array {
    func callAsFunction(_ i: Index) -> Element? {
        guard i < count else { return nil }
        return self[i]
    }
}
