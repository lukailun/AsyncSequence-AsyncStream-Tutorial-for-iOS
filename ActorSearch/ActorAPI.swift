import SwiftUI

struct Actor: Identifiable {
    let id = UUID()
    let name: String
}

class ActorAPI: ObservableObject {
    @Published private(set) var actors: [Actor] = []
    let filename: String
    let url: URL

    init(filename: String) {
        self.filename = filename
        url = Bundle.main.url(forResource: filename, withExtension: "tsv")!
    }

    // Synchronous read
    func readSync() throws {
        let start = Date.now
        let contents = try String(contentsOf: url)
        var counter = 0
        contents.enumerateLines { _, _ in
            counter += 1
        }
        print("\(counter) lines")
        print("Duration: \(Date.now.timeIntervalSince(start))")
    }

    // Asynchronous read
    func readAsync() async throws {
        let start = Date.now
        var counter = 0
        for try await _ in url.lines {
            counter += 1
        }
        print("\(counter) lines")
        print("Duration: \(Date.now.timeIntervalSince(start))")
    }

    // AsyncStream: push-based
    func pushActors() async {
        let actorStream = AsyncStream<Actor> { continuation in
            Task {
                for try await line in url.lines {
                    let name = line.components(separatedBy: "\t")[1]
                    continuation.yield(Actor(name: name))
                }
                continuation.finish()
            }
        }

        for await actor in actorStream {
            await MainActor.run {
                actors.append(actor)
            }
        }
    }

    // AsyncStream: pull-based
    func pullActors() async {
        var iterator = url.lines.makeAsyncIterator()
        let actorStream = AsyncStream<Actor> {
            do {
                if let line = try await iterator.next(), !line.isEmpty {
                    let name = line.components(separatedBy: "\t")[1]
                    return Actor(name: name)
                }
            } catch {
                print(error.localizedDescription)
            }
            return nil
        }
        for await actor in actorStream {
            await MainActor.run {
                actors.append(actor)
            }
        }
    }

    func getActors() async {
        for await actor in ActorSequence(filename: filename) {
            await MainActor.run {
                actors.append(actor)
            }
        }
    }
}

// AsyncSequence of Actors
struct ActorSequence: AsyncSequence {
    typealias Element = Actor
    typealias AsyncIterator = ActorIterator

    let filename: String
    let url: URL

    init(filename: String) {
        self.filename = filename
        url = Bundle.main.url(forResource: filename, withExtension: "tsv")!
    }

    func makeAsyncIterator() -> ActorIterator {
        return ActorIterator(url: url)
    }
}

struct ActorIterator: AsyncIteratorProtocol {
    let url: URL
    var iterator: AsyncLineSequence<URL.AsyncBytes>.AsyncIterator

    init(url: URL) {
        self.url = url
        iterator = url.lines.makeAsyncIterator()
    }

    mutating func next() async -> Actor? {
        do {
            if let line = try await iterator.next(), !line.isEmpty {
                let name = line.components(separatedBy: "\t")[1]
                return Actor(name: name)
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
}
