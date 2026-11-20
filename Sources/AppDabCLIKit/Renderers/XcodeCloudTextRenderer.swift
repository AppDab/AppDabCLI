import AppDabServices
import Foundation

struct XcodeCloudTextRenderer {
    func render(_ list: XcodeCloudWorkflowList, style: TextStyle) -> String {
        let table = TextTable(
            headers: ["Name", "Workflow ID", "Repository ID", "Enabled"],
            rows: list.workflows.map { [$0.name, $0.workflowID, $0.repositoryID ?? "-", yesNo($0.isEnabled)] },
        )
        return [
            style.heading("Xcode Cloud workflows (\(list.workflows.count) of \(list.pagination.total))"),
            list.workflows.isEmpty ? "No workflows found." : table.render(style: style),
        ].joined(separator: "\n\n")
    }

    func render(_ workflow: XcodeCloudWorkflow, style: TextStyle) -> String {
        [
            style.heading("Xcode Cloud workflow"),
            TextDetails(rows: [
                ("Name", workflow.name),
                ("Workflow ID", workflow.workflowID),
                ("Repository ID", workflow.repositoryID ?? "-"),
                ("Enabled", yesNo(workflow.isEnabled)),
                ("Locked for editing", yesNo(workflow.isLockedForEditing)),
                ("Last modified", workflow.lastModifiedDate?.formatted(.iso8601) ?? "-"),
            ]).render(style: style),
        ].joined(separator: "\n\n")
    }

    func render(_ list: XcodeCloudGitReferenceList, style: TextStyle) -> String {
        let table = TextTable(
            headers: ["Name", "Kind", "Canonical Name", "Git Reference ID", "Deleted"],
            rows: list.gitReferences.map { [$0.name, $0.kind ?? "-", $0.canonicalName ?? "-", $0.gitReferenceID, yesNo($0.isDeleted)] },
        )
        return [
            style.heading("Xcode Cloud Git references (\(list.gitReferences.count) of \(list.pagination.total))"),
            list.gitReferences.isEmpty ? "No Git references found." : table.render(style: style),
        ].joined(separator: "\n\n")
    }

    func render(_ run: XcodeCloudBuildRun, heading: String, style: TextStyle) -> String {
        [
            style.heading(heading),
            TextDetails(rows: [
                ("Build run ID", run.buildRunID),
                ("Build number", run.number.map(String.init) ?? "-"),
                ("Workflow ID", run.workflowID ?? "-"),
                ("Git reference ID", run.sourceBranchOrTagID ?? "-"),
                ("Progress", run.executionProgress ?? "-"),
                ("Completion status", run.completionStatus ?? "-"),
                ("Created", run.createdDate?.formatted(.iso8601) ?? "-"),
                ("Started", run.startedDate?.formatted(.iso8601) ?? "-"),
                ("Finished", run.finishedDate?.formatted(.iso8601) ?? "-"),
            ]).render(style: style),
        ].joined(separator: "\n\n")
    }

    private func yesNo(_ value: Bool?) -> String {
        value.map { $0 ? "Yes" : "No" } ?? "-"
    }
}
