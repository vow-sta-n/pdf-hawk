import 'package:pdfhawk/data/models/device_document_model.dart';

class FolderDirectoryGroup {
  final String directoryPath;
  final String folderName;
  final List<DeviceDocumentModel> documents;
  final int totalSize;

  const FolderDirectoryGroup({
    required this.directoryPath,
    required this.folderName,
    required this.documents,
    required this.totalSize,
  });
}