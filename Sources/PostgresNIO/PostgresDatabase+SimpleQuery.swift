import NIOCore
import Logging

extension PostgresDatabase {
    public func simpleQuery(_ string: String) -> EventLoopFuture<[PostgresRow]> {
        var rows: [PostgresRow] = []
        return simpleQuery(string) { rows.append($0) }.map { rows }
    }
    
    public func simpleQuery(_ string: String, _ onRow: @escaping (PostgresRow) throws -> ()) -> EventLoopFuture<Void> {
        self.query(string, onRow: onRow)
    }
    
    #if canImport(_Concurrency)
    public func simpleQuery(_ string: String) async throws -> [PostgresRow] {
        let future: EventLoopFuture<[PostgresRow]> = simpleQuery(string)
        return try await withCheckedThrowingContinuation { cont in
            future.whenSuccess { val in
                cont.resume(returning: val)
            }
            future.whenFailure { error in
                cont.resume(throwing: error)
            }
        }
    }
    
    public func simpleQuery(_ string: String, _ onRow: @escaping (PostgresRow) throws -> ()
    ) async throws {
        let future: EventLoopFuture<Void> = simpleQuery(string, onRow)
        return try await withCheckedThrowingContinuation { cont in
            future.whenSuccess { val in
                cont.resume(returning: val)
            }
            future.whenFailure { error in
                cont.resume(throwing: error)
            }
        }
    }
    #endif
}
