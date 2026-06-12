import 'package:flutter/material.dart';

import 'issue_detail_sheet.dart';

/// Deep-link / route target for `/issues/:id`. Reuses the shared editable
/// [IssueDetailBody]; the primary in-app entry point is the modal sheet
/// (`showIssueDetailSheet`).
class IssueDetailScreen extends StatelessWidget {
  const IssueDetailScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: IssueDetailBody(issueId: issueId),
      ),
    );
  }
}
