import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/connectivity_cubit.dart';
import 'package:paperless_mobile/core/bloc/loading_status.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/state/pm_error_state.dart';
import 'package:paperless_mobile/core/widgets/state/pm_loading_state.dart';
import 'package:paperless_mobile/features/document_details/cubit/document_details_cubit.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_content_widget.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_download_button.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_info_widget.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_notes_widget.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_share_button.dart';
import 'package:paperless_mobile/features/documents/view/widgets/delete_document_confirmation_dialog.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';
import 'package:paperless_mobile/theme.dart';

class DocumentDetailsPage extends StatefulWidget {
  final int id;
  final String? title;
  final bool isLabelClickable;
  final String? titleAndContentQueryString;
  final String? thumbnailUrl;
  final String? heroTag;

  const DocumentDetailsPage({
    super.key,
    this.isLabelClickable = true,
    this.titleAndContentQueryString,
    this.thumbnailUrl,
    required this.id,
    this.heroTag,
    this.title,
  });

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initializeDateFormatting(Localizations.localeOf(context).toString());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: buildOverlayStyle(
        Theme.of(context),
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
      ),
      child: BlocBuilder<DocumentDetailsCubit, DocumentDetailsState>(
        builder: (context, state) {
          return Scaffold(
            extendBodyBehindAppBar: false,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildAppBar(context, state, innerBoxIsScrolled),
              ],
              body: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: S.of(context)!.overview),
                      Tab(text: S.of(context)!.content),
                      Tab(
                        text:
                            state.status == LoadingStatus.loaded &&
                                state.document!.notes.isNotEmpty
                            ? '${S.of(context)!.notes(0)} (${state.document!.notes.length})'
                            : S.of(context)!.notes(0),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(context, state),
                        _buildContentTab(context, state),
                        _buildNotesTab(context, state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomActionBar(context, state),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    DocumentDetailsState state,
    bool innerBoxIsScrolled,
  ) {
    final title = switch (state.status) {
      LoadingStatus.loaded => state.document!.title,
      _ => widget.title ?? '',
    };

    String? subtitle;
    if (state.status == LoadingStatus.loaded) {
      final doc = state.document!;
      final dateFormat = DateFormat.yMMMMd(
        Localizations.localeOf(context).toString(),
      );
      final correspondent = doc.correspondent != null
          ? context
                .read<LabelRepository>()
                .correspondents[doc.correspondent]
                ?.name
          : null;
      subtitle = correspondent != null
          ? '$correspondent · ${dateFormat.format(doc.created)}'
          : dateFormat.format(doc.created);
    }

    return SliverAppBar.large(
      leading: const BackButton(),
      pinned: true,
      stretch: true,
      forceElevated: innerBoxIsScrolled,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 80),
        background: GestureDetector(
          onTap: () {
            DocumentPreviewRoute(id: widget.id, title: title).push(context);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: widget.heroTag ?? "thumb_${widget.id}",
                child: DocumentPreview(
                  documentId: widget.id,
                  title: title,
                  enableHero: false,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.open_in_full),
          tooltip: S.of(context)!.openInSystemViewer,
          onPressed: state.status == LoadingStatus.loaded
              ? () => DocumentPreviewRoute(
                  id: widget.id,
                  title: title,
                ).push(context)
              : null,
        ),
        PopupMenuButton<String>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: const Icon(Icons.share),
                title: Text(S.of(context)!.shareTooltip),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'download',
              child: ListTile(
                leading: const Icon(Icons.download),
                title: Text(S.of(context)!.downloadDocumentTooltip),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'print',
              child: ListTile(
                leading: const Icon(Icons.print),
                title: Text(S.of(context)!.print),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete),
                title: Text(S.of(context)!.deleteDocumentTooltip),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            if (state.status != LoadingStatus.loaded) return;
            switch (value) {
              case 'share':
                // Handle via state widget
                break;
              case 'download':
                // Handle via state widget
                break;
              case 'print':
                context.read<DocumentDetailsCubit>().printDocument();
                break;
              case 'delete':
                _onDelete(state.document!);
                break;
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoTab(BuildContext context, DocumentDetailsState state) {
    return switch (state.status) {
      LoadingStatus.loaded => DocumentInfoWidget(
        document: state.document!,
        metaData: state.metaData,
        queryString: widget.titleAndContentQueryString,
      ),
      LoadingStatus.error => Center(
        child: PmErrorState(title: S.of(context)!.couldNotLoadDocument),
      ),
      _ => const Center(child: PmLoadingState()),
    };
  }

  Widget _buildContentTab(BuildContext context, DocumentDetailsState state) {
    return switch (state.status) {
      LoadingStatus.loaded => SingleChildScrollView(
        padding: PmSpacing.pagePadding,
        child: DocumentContentWidget(
          document: state.document!,
          queryString: widget.titleAndContentQueryString,
        ),
      ),
      LoadingStatus.error => Center(
        child: PmErrorState(title: S.of(context)!.couldNotLoadDocument),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildNotesTab(BuildContext context, DocumentDetailsState state) {
    return switch (state.status) {
      LoadingStatus.loaded => DocumentNotesWidget(document: state.document!),
      LoadingStatus.error => Center(
        child: PmErrorState(title: S.of(context)!.couldNotLoadDocument),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget? _buildBottomActionBar(
    BuildContext context,
    DocumentDetailsState state,
  ) {
    if (state.status != LoadingStatus.loaded) return null;

    final isOnline = context.watchInternetConnection;
    final currentUser = context.watch<LocalUserAccount>();
    final canEdit = currentUser.paperlessUser.canEditDocuments && isOnline;

    return Material(
      elevation: PmElevations.level2,
      child: SafeArea(
        child: Padding(
          padding: PmSpacing.pagePadding,
          child: Row(
            children: [
              if (canEdit)
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(S.of(context)!.edit),
                    onPressed: () =>
                        EditDocumentRoute(state.document!).push(context),
                  ),
                ),
              if (canEdit) const SizedBox(width: PmSpacing.md),
              DocumentShareButton(document: state.document, enabled: isOnline),
              const SizedBox(width: PmSpacing.xs),
              DocumentDownloadButton(
                document: state.document,
                enabled: isOnline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDelete(DocumentModel document) async {
    final delete =
        await showDialog(
          context: context,
          builder: (context) =>
              DeleteDocumentConfirmationDialog(document: document),
        ) ??
        false;
    if (delete) {
      try {
        if (mounted) {
          await context.read<DocumentDetailsCubit>().delete(document);
          // showSnackBar(context, S.of(context)!.documentSuccessfullyDeleted);
        }
      } on PaperlessApiException catch (error, stackTrace) {
        if (mounted) {
          showErrorMessage(context, error, stackTrace);
        }
      } finally {
        if (mounted) {
          context.pop();
        }
      }
    }
  }
}
