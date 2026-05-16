import 'dart:convert';

import 'package:equatable/equatable.dart';

const paperlessChatMetadataDelimiter = '\n\n__PAPERLESS_CHAT_METADATA__';

class AiChatReference extends Equatable {
  final int id;
  final String title;

  const AiChatReference({required this.id, required this.title});

  factory AiChatReference.fromJson(Map<String, dynamic> json) {
    return AiChatReference(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, title];
}

class AiChatResponse extends Equatable {
  final String content;
  final List<AiChatReference> references;

  const AiChatResponse({required this.content, this.references = const []});

  factory AiChatResponse.parse(String response) {
    // paperless-ngx streams answer text first, then appends JSON metadata with
    // references after a sentinel delimiter.
    final delimiterIndex = response.indexOf(paperlessChatMetadataDelimiter);
    if (delimiterIndex == -1) {
      return AiChatResponse(content: response);
    }

    final content = response.substring(0, delimiterIndex);
    final metadata = response.substring(
      delimiterIndex + paperlessChatMetadataDelimiter.length,
    );

    try {
      final decoded = jsonDecode(metadata);
      final references = decoded is Map<String, dynamic>
          ? decoded['references']
          : null;
      return AiChatResponse(
        content: content,
        references: references is Iterable
            ? references
                  .whereType<Map<String, dynamic>>()
                  .map(AiChatReference.fromJson)
                  .toList()
            : const [],
      );
    } catch (_) {
      return AiChatResponse(content: content);
    }
  }

  @override
  List<Object?> get props => [content, references];
}
