import GRPC
import NIOCore
import NIOPosix

public class AudioStreamServer {
  private var port: Int
  private var server: Server!
  private var group: MultiThreadedEventLoopGroup!

  public init(port: Int) {
    self.port = port
  }

  public func run() async throws {
    // print("hello")
    group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try! group.syncShutdownGracefully()
    }

    // Start the server and print its address once it has started.
    server = try await Server.insecure(group: group)
      .withServiceProviders([AudioService()])
      .bind(host: "localhost", port: self.port)
      .get()

    print("server started on port \(server.channel.localAddress!.port!)")

    // Wait on the server's `onClose` future to stop the program from exiting.
    try await server.onClose.get()
  }

  public func stop() {
    try? server.close().wait()
    try? group.syncShutdownGracefully()
  }
}


