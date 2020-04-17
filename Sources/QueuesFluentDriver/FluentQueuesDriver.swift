import Fluent
import Queues

public struct FluentQueuesDriver {
    let databaseId: DatabaseID?
    let useSoftDeletes: Bool
    
    init(on databaseId: DatabaseID? = nil, useSoftDeletes: Bool) {
        self.databaseId = databaseId
        self.useSoftDeletes = useSoftDeletes
    }
}

extension FluentQueuesDriver: QueuesDriver {
    
    public func makeQueue(with context: QueueContext) -> Queue {
        let db = context
            .application
            .databases
            .database(databaseId, logger: context.logger, on: context.eventLoop)

        return FluentQueue(db: db, context: context, useSoftDeletes: self.useSoftDeletes)
    }
    
    public func shutdown() {}
    
}
