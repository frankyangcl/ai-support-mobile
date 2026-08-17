class Citation {
  const Citation({
    required this.filename,
    this.documentId,
    this.chunkIndex,
    this.distance,
    this.preview,
  });

  final String filename;
  final Object? documentId;
  final int? chunkIndex;
  final double? distance;
  final String? preview;

  static Citation? tryFromJson(Map<String, Object?> json) {
    final filename = json['filename'];
    if (filename is! String || filename.isEmpty) return null;
    final rawChunkIndex = json['chunk_index'];
    final rawDistance = json['distance'];
    final rawPreview = json['preview'];
    return Citation(
      filename: filename,
      documentId: json['document_id'],
      chunkIndex: rawChunkIndex is num ? rawChunkIndex.toInt() : null,
      distance: rawDistance is num ? rawDistance.toDouble() : null,
      preview:
          rawPreview is String && rawPreview.isNotEmpty ? rawPreview : null,
    );
  }
}
