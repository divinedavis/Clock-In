import SwiftUI
import PDFKit

struct PDFFormEditor: UIViewRepresentable {
    let data: Data
    @Binding var document: PDFDocument?

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemGroupedBackground
        let doc = PDFDocument(data: data)
        view.document = doc
        DispatchQueue.main.async { self.document = doc }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
