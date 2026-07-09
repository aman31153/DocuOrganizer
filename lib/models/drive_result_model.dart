import 'doc_model.dart';

class DrivePaginatedResult {
  final List<DocModel> files;
  final String? nextPageToken;
  DrivePaginatedResult(this.files, this.nextPageToken);
}
