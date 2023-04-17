import Foundation

class ActionsNodeBase {
    let actions: [Action]
    var rest: [any Node<DefaultIO>]
    
    init(actions: [Action] = [], rest: [any Node<DefaultIO>] = []) {
        self.actions = actions
        self.rest = rest
    }
    
    func makeOutput(_ rest: [DefaultIO]) -> [DefaultIO] {
        rest.reduce(into: []) {
            $0.append(DefaultIO($1.match, $1.event, $1.state, actions + $1.actions))
        }
    }
}

class ActionsNode: ActionsNodeBase, Node {
    func combinedWithRest(_ rest: [DefaultIO]) -> [DefaultIO] {
        makeOutput(rest) ??? makeDefaultIO(actions: actions)
    }
}

class ActionsBlockNode: ActionsNodeBase, NeverEmptyNode {
    let caller: String
    let file: String
    let line: Int
    
    init(
        actions: [Action],
        rest: [any Node<Input>],
        caller: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        self.caller = caller
        self.file = file
        self.line = line
        
        super.init(actions: actions, rest: rest)
    }
    
    func combinedWithRest(_ rest: [DefaultIO]) -> [DefaultIO] {
        makeOutput(rest)
    }
}
