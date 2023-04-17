import Foundation

class WhenNodeBase {
    let events: [AnyTraceable]
    var rest: [any Node<DefaultIO>]
    
    let caller: String
    let file: String
    let line: Int
    
    init(
        events: [AnyTraceable],
        rest: [any Node<DefaultIO>] = [],
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        self.events = events
        self.rest = rest
        self.caller = caller
        self.file = file
        self.line = line
    }
    
    func makeOutput(_ rest: [DefaultIO], _ event: AnyTraceable) -> [DefaultIO] {
        rest.reduce(into: []) {
            $0.append(DefaultIO($1.match, event, $1.state, $1.actions))
        }
    }
}

class WhenNode: WhenNodeBase, NeverEmptyNode {
    func combinedWithRest(_ rest: [DefaultIO]) -> [DefaultIO] {
        events.reduce(into: []) { output, event in
            output.append(contentsOf: makeOutput(rest, event) ??? makeDefaultIO(event: event))
        }
    }
    
    func validate() -> [Error] {
        makeError(if: events.isEmpty)
    }
}

class WhenBlockNode: WhenNodeBase, NeverEmptyNode {
    func combinedWithRest(_ rest: [DefaultIO]) -> [DefaultIO] {
        events.reduce(into: []) { output, event in
            output.append(contentsOf: makeOutput(rest, event))
        }
    }
    
    func validate() -> [Error] {
        makeError(if: events.isEmpty || rest.isEmpty)
    }
}
