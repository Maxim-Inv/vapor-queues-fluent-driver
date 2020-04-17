import Foundation
import Fluent
import Queues

public enum QueuesFluentJobState: String, Codable {
    /// Ready to be picked up for execution
    case pending
    case processing
    /// Executed, regardless if it was successful or not
    case completed
}

extension FieldKey {
    static var queue: Self { "queue" }
    static var data: Self { "data" }
    static var state: Self { "state" }

    static var createdAt: Self { "created_at" }
    static var updatedAt: Self { "updated_at" }
    static var deletedAt: Self { "deleted_at" }
}

class JobModel: Model {
    
    public static var schema = "jobs"
    
    /// The unique Job uuid
    @ID(key: .id)
    var id: UUID?
    
    /// The job queue name
    @Field(key: .queue)
    var queue: String
    
    /// The Job data
    @Field(key: .data)
    var data: JobData
    
    /// The current state of the Job
    @Field(key: .state)
    var state: QueuesFluentJobState
    
    /// The created timestamp
    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?
    
    /// The updated timestamp
    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?
    
    /// The deleted timestamp
    @Timestamp(key: .deletedAt, on: .delete)
    var deletedAt: Date?
    
    public required init() {}

    init(id: UUID, queue: String, data: JobData) {
        self.id = id
        self.queue = queue
        self.data = data
        self.state = .pending
    }
}
