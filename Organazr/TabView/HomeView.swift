import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // действие кнопки «+»
                        } label: {
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
            .navigationTitle("Дом")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // …
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // …
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .foregroundStyle(.black)
        }
    }
}
