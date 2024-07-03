import SwiftUI

struct ContentView: View {
    @StateObject private var model = ActorAPI(filename: "data-100")
    @State private var nameSearch = ""

    var body: some View {
        NavigationView {
            List {
                Section(content: {
                    if model.actors.isEmpty {
                        ProgressView().padding()
                    }
                    ForEach(model.actors) { actor in
                        Text(actor.name)
                    }
                }, header: Header.init)
            }
        }
        .searchable(text: $nameSearch) {
            let matches = model.actors.filter { actor in
                actor.name.contains(nameSearch)
            }
            if matches.isEmpty { NothingView() }
            ForEach(matches) { actor in
                Text(actor.name)
            }
        }
//        .onAppear {
//          do {
//            try model.readSync()
//          } catch let error {
//            print(error.localizedDescription)
//          }
//        }
        .task {
            await model.pushActors()
        }
    }
}

struct Header: View {
    var body: some View {
        Label(" Actor Search", systemImage: "theatermasks")
            .foregroundColor(Color(uiColor: .systemBlue))
            .font(.custom("FantasqueSansMono-Regular", size: 34))
            .padding(.bottom, 20)
    }
}

struct NothingView: View {
    var body: some View {
        Text("No items")
    }
}
