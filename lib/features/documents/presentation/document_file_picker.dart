import 'package:file_picker/file_picker.dart';

class PickedDocument {
  const PickedDocument({required this.filename, required this.bytes});
  final String filename;
  final List<int> bytes;
}

abstract interface class DocumentFilePicker {
  Future<PickedDocument?> pickPdf();
}

class SystemDocumentFilePicker implements DocumentFilePicker {
  const SystemDocumentFilePicker();

  @override
  Future<PickedDocument?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.bytes == null) {
      throw const FilePickerException('The selected PDF could not be read.');
    }
    return PickedDocument(filename: file.name, bytes: file.bytes!);
  }
}

class FilePickerException implements Exception {
  const FilePickerException(this.message);
  final String message;
}
