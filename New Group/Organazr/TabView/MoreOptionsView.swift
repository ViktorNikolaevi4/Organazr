import SwiftUI

struct MoreOptionsView: View {
    var body: some View {
        ZStack {
            // фон на весь экран
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Верхняя панель из четырёх кнопок
                HStack(spacing: 16) {
                    OptionButton(
                        systemName: "pin.fill",
                        title: "Закрепить",
                        bgColor: .yellow
                    )
                    OptionButton(
                        systemName: "square.and.arrow.up",
                        title: "Поделиться",
                        bgColor: .green
                    )
                    OptionButton(
                        systemName: "xmark.circle.fill",
                        title: "Не буду делать",
                        bgColor: .blue
                    )
                    OptionButton(
                        systemName: "trash.fill",
                        title: "Удалить",
                        bgColor: .red
                    )
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
        }
    }
}

private struct OptionButton: View {
    let systemName: String
    let title: String
    let bgColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Button {
                // TODO
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 18))
                    .foregroundColor(bgColor)          // иконка — в цвете bgColor
                    .frame(width: 56, height: 56)
                    .background(Color.white)           // фон — белый
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(                          // тонкая граница
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(bgColor, lineWidth: 1)
                    )
            }

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

