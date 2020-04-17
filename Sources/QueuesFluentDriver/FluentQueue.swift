import Foundation
import Queues
import Fluent

struct FluentQueue {
    let db: Database?
    let context: QueueContext
    let useSoftDeletes: Bool
}

extension FluentQueue: Queue {
    
    func get(_ id: JobIdentifier) -> EventLoopFuture<JobData> {
        guard let db = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return db.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        
        return JobModel.query(on: db)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .map { $0.data }
    }
    
    func set(_ id: JobIdentifier, to jobData: JobData) -> EventLoopFuture<Void> {
        guard let db = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return db.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }

        return JobModel(id: uuid, queue: queueName.string, data: jobData).save(on: db)
    }
    
    func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return JobModel.query(on: database)
            .filter(\.$id == uuid)
            .filter(\.$state != QueuesFluentJobState.completed)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                if self.useSoftDeletes {
                    job.state = .completed
                    job.deletedAt = Date()
                    
                    return job.update(on: database)
                } else {
                    return job.delete(force: true, on: database)
                }
        }
    }
    
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        
        return JobModel.query(on: database)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                job.state = QueuesFluentJobState.pending
                
                return job.save(on: database)
            }
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let db = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        
        return JobModel.query(on: db)
            .filter(\.$state == QueuesFluentJobState.pending)
            .filter(\.$queue == self.queueName.string)
            .sort(\.$createdAt, .ascending)
            .first()
            .flatMap { job -> EventLoopFuture<JobIdentifier?> in
                guard let job = job else {
                    return db.eventLoop.future(nil)
                }
                
                job.state = QueuesFluentJobState.processing

                return job.save(on: db).map {
                    guard let id = job.id else {
                        return nil
                    }
                    
                    return JobIdentifier(string: id.uuidString)
                }
            }
    }
    
    
    /// /!\ This is a non standard extension.
    public func list(queue: String? = nil, state: QueuesFluentJobState = .pending) -> EventLoopFuture<[JobData]> {
        guard let db = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        
        var query = JobModel.query(on: db)
            .filter(\.$state == state)
            
        if let queue = queue {
            query = query.filter(\.$queue == queue)
        }

        return query
            .all()
            .map { $0.map
                { $0.data }
            }
    }
}

public struct JobInfo: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var completedAt: Date?
}
