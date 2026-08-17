class Citation {
  const Citation({required this.filename});
  final String filename;

  static Citation? tryFromJson(Map<String, Object?> json) {
    final filename = json['filename'];
    return filename is String && filename.isNotEmpty
        ? Citation(filename: filename)
        : null;
  }
}
