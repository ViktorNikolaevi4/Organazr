import SwiftUI
import SwiftData


struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @State private var isAdding = false

    var body: some View {
            NavigationStack {
                ZStack {
                    Color(.systemGray6).ignoresSafeArea()

                    List {
                        ForEach(tasks) { task in
                            HStack {
                                Image(systemName: "square")
                                Text(task.title)
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)

                    plusButton
                }
                .navigationTitle("Задачи")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { /* … */ } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { /* … */ } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
                .sheet(isPresented: $isAdding) {
                    AddTaskSheet { newTitle in
                        addTask(title: newTitle)
                        isAdding = false
                    }
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
        }

        // MARK: –– UI

        private var plusButton: some View {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { isAdding = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 64))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .specialBlue)
                            .shadow(radius: 4, y: 2)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }
        }

        // MARK: –– Data operations

        private func addTask(title: String) {
            let newItem = TaskItem(title: title)
            modelContext.insert(newItem)
        }

        private func delete(at offsets: IndexSet) {
            for idx in offsets {
                modelContext.delete(tasks[idx])
            }
        }
    }
