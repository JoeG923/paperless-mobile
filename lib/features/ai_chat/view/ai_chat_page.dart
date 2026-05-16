import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/ai/model/ai_feature_status.dart';
import 'package:paperless_mobile/routing/routes.dart';
import 'package:provider/provider.dart';

class AiChatPage extends StatefulWidget {
  final int? documentId;
  final String title;
  final String scopeLabel;
  final String? initialPrompt;

  const AiChatPage({
    super.key,
    this.documentId,
    required this.title,
    required this.scopeLabel,
    this.initialPrompt,
  });

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _messages = <_AiChatMessage>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  CancelToken? _cancelToken;
  bool _isStreaming = false;
  bool _showPrivacyNotice = true;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialPrompt ?? '';
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiStatus = context.watch<AiFeatureStatus>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PmSpacing.lg,
                0,
                PmSpacing.lg,
                PmSpacing.sm,
              ),
              child: Text(
                widget.scopeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (aiStatus.enabled && !aiStatus.isIndexHealthy)
            _AiStatusNotice(status: aiStatus),
          if (_showPrivacyNotice)
            _AiPrivacyNotice(
              onDismissed: () {
                setState(() => _showPrivacyNotice = false);
              },
            ),
          Expanded(
            child: _messages.isEmpty
                ? _AiChatEmptyState(
                    documentScoped: widget.documentId != null,
                    onPromptSelected: (prompt) {
                      _controller.text = prompt;
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      PmSpacing.lg,
                      PmSpacing.md,
                      PmSpacing.lg,
                      PmSpacing.xxl,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _AiChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: PmElevations.level2,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PmSpacing.lg,
            PmSpacing.sm,
            PmSpacing.lg,
            PmSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question',
                    prefixIcon: Icon(Icons.auto_awesome_outlined),
                  ),
                  onSubmitted: (_) => _isStreaming ? null : _send(),
                  enabled: !_isStreaming,
                ),
              ),
              const SizedBox(width: PmSpacing.sm),
              IconButton.filled(
                tooltip: _isStreaming ? 'Stop' : 'Send',
                icon: Icon(_isStreaming ? Icons.stop_rounded : Icons.send),
                onPressed: _isStreaming ? _stop : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    final userMessage = _AiChatMessage.user(prompt);
    final assistantMessage = _AiChatMessage.assistant();
    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _controller.clear();
      _isStreaming = true;
    });
    _scrollToBottom();

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      await for (final response
          in context.read<PaperlessDocumentsApi>().streamChat(
            documentId: widget.documentId,
            prompt: prompt,
            cancelToken: cancelToken,
          )) {
        if (!mounted) return;
        setState(() {
          assistantMessage.content = response.content;
          assistantMessage.references = response.references;
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted || (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      setState(() {
        assistantMessage.content = 'AI could not answer this request.';
      });
    } finally {
      if (mounted) {
        setState(() => _isStreaming = false);
      }
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  void _stop() {
    _cancelToken?.cancel('User stopped AI response.');
    setState(() => _isStreaming = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: PmDurations.short,
        curve: Curves.easeOut,
      );
    });
  }
}

class _AiChatMessage {
  final bool isUser;
  String content;
  List<AiChatReference> references;

  _AiChatMessage.user(this.content) : isUser = true, references = const [];

  _AiChatMessage.assistant()
    : isUser = false,
      content = '',
      references = const [];
}

class _AiChatBubble extends StatelessWidget {
  final _AiChatMessage message;

  const _AiChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isUser
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final textColor = message.isUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PmSpacing.xs),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: PmRadii.rlg,
              ),
              child: Padding(
                padding: PmSpacing.cardPadding,
                child: Text(
                  message.content.isEmpty ? 'Thinking...' : message.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
            ),
          ),
          if (!message.isUser && message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PmSpacing.xs),
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied answer')),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ),
          if (message.references.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PmSpacing.sm),
              child: _AiReferences(references: message.references),
            ),
        ],
      ),
    );
  }
}

class _AiReferences extends StatelessWidget {
  final List<AiChatReference> references;

  const _AiReferences({required this.references});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('References', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: PmSpacing.xs),
        for (final reference in references)
          Card(
            margin: const EdgeInsets.only(bottom: PmSpacing.xs),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text(reference.title),
              onTap: () => context.pushNamed(
                R.documentDetails,
                pathParameters: {'id': reference.id.toString()},
                queryParameters: {'title': reference.title},
              ),
            ),
          ),
      ],
    );
  }
}

class _AiChatEmptyState extends StatelessWidget {
  final bool documentScoped;
  final ValueChanged<String> onPromptSelected;

  const _AiChatEmptyState({
    required this.documentScoped,
    required this.onPromptSelected,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = documentScoped
        ? const [
            'Summarize this document',
            'What dates matter?',
            'What action is required?',
          ]
        : const [
            'Find unpaid invoices',
            'What documents need action?',
            'Summarize recent tax documents',
          ];
    return Center(
      child: Padding(
        padding: PmSpacing.pagePadding,
        child: Wrap(
          spacing: PmSpacing.sm,
          runSpacing: PmSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final prompt in prompts)
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(prompt),
                onPressed: () => onPromptSelected(prompt),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiStatusNotice extends StatelessWidget {
  final AiFeatureStatus status;

  const _AiStatusNotice({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.lg,
          vertical: PmSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: PmSpacing.sm),
            Expanded(
              child: Text(
                status.llmIndexError?.isNotEmpty == true
                    ? status.llmIndexError!
                    : 'AI index needs attention.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiPrivacyNotice extends StatelessWidget {
  final VoidCallback onDismissed;

  const _AiPrivacyNotice({required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.lg,
          vertical: PmSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: PmSpacing.sm),
            Expanded(
              child: Text(
                'AI requests go to your paperless-ngx server. The server decides whether document content is processed locally or by a remote model.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              onPressed: onDismissed,
            ),
          ],
        ),
      ),
    );
  }
}
