// App/IconViewModel+ImportNotice.swift
import Foundation

extension IconViewModel {
    /// Shows a notice when the change from `previous` was a background import that
    /// changed other settings. Call only for user edits: undo, redo and a
    /// configuration import must not raise one.
    func observeImport(from previous: IconSettings) {
        if let notice = ImportNotice.detect(from: previous, to: iconSettings) {
            importNotice = notice
        }
    }

    /// Puts back what the shown notice's import changed, and dismisses it.
    func revertImportNotice() {
        guard let notice = importNotice else { return }
        notice.revert(&iconSettings)
        importNotice = nil
    }
}
