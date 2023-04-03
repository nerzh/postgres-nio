import NIOCore
import Logging

public protocol PostgresDatabase {
    var logger: Logger { get }
    var eventLoop: EventLoop { get }
    func send(
        _ request: PostgresRequest,
        logger: Logger
    ) -> EventLoopFuture<Void>
    
    func withConnection<T>(_ closure: @escaping (PostgresConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T>
    
    #if canImport(_Concurrency)
    func send(
        _ request: PostgresRequest,
        logger: Logger
    ) async throws
    
    func withConnection<T>(_ closure: @escaping (PostgresConnection) async throws -> T) async throws -> T
    #endif
}

extension PostgresDatabase {
    public func logging(to logger: Logger) -> PostgresDatabase {
        _PostgresDatabaseCustomLogger(database: self, logger: logger)
    }
}

private struct _PostgresDatabaseCustomLogger {
    let database: PostgresDatabase
    let logger: Logger
}

extension _PostgresDatabaseCustomLogger: PostgresDatabase {
    var eventLoop: EventLoop {
        self.database.eventLoop
    }
    
    func send(_ request: PostgresRequest, logger: Logger) -> EventLoopFuture<Void> {
        self.database.send(request, logger: logger)
    }
    
    func withConnection<T>(_ closure: @escaping (PostgresConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.database.withConnection(closure)
    }
    
    #if canImport(_Concurrency)
    func send(_ request: PostgresRequest, logger: Logging.Logger) async throws {
        let future: EventLoopFuture<Void> = send(request, logger: logger)
        return try await withCheckedThrowingContinuation { cont in
            future.whenSuccess { val in
                cont.resume(returning: val)
            }
            future.whenFailure { error in
                cont.resume(throwing: error)
            }
        }
    }
    
    func withConnection<T>(_ closure: @escaping (PostgresConnection) async throws -> T) async throws -> T {
        let fun: (PostgresConnection) -> EventLoopFuture<T> = { conn in
            let promise: EventLoopPromise<T> = eventLoop.any().makePromise()
            Task {
                do {
                    promise.succeed(try await closure(conn))
                } catch {
                    promise.fail(error)
                }
            }
            return promise.futureResult
        }
        let future: EventLoopFuture<T> = withConnection(fun)
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
