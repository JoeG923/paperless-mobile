import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';

part 'label_cubit.freezed.dart';
part 'label_state.dart';

class LabelCubit extends Cubit<LabelState> {
  final LabelRepository labelRepository;

  LabelCubit(this.labelRepository) : super(const LabelState()) {
    labelRepository.addListener(_updateStateListener);
  }

  void _updateStateListener() {
    emit(
      state.copyWith(
        correspondents: labelRepository.correspondents,
        documentTypes: labelRepository.documentTypes,
        storagePaths: labelRepository.storagePaths,
        tags: labelRepository.tags,
      ),
    );
  }

  Future<void> reload({
    required bool loadCorrespondents,
    required bool loadDocumentTypes,
    required bool loadStoragePaths,
    required bool loadTags,
  }) {
    return labelRepository.initialize(
      loadCorrespondents: loadCorrespondents,
      loadDocumentTypes: loadDocumentTypes,
      loadStoragePaths: loadStoragePaths,
      loadTags: loadTags,
    );
  }

  Future<Correspondent> addCorrespondent(Correspondent item) async {
    assert(item.id == null);
    final addedItem = await labelRepository.createCorrespondent(item);
    return addedItem;
  }

  Future<void> reloadCorrespondents() {
    return labelRepository.findAllCorrespondents();
  }

  Future<Correspondent> replaceCorrespondent(Correspondent item) async {
    assert(item.id != null);
    final updatedItem = await labelRepository.updateCorrespondent(item);
    return updatedItem;
  }

  Future<void> removeCorrespondent(Correspondent item) async {
    assert(item.id != null);
    if (labelRepository.correspondents.containsKey(item.id)) {
      await labelRepository.deleteCorrespondent(item);
    }
  }

  Future<DocumentType> addDocumentType(DocumentType item) async {
    assert(item.id == null);
    final addedItem = await labelRepository.createDocumentType(item);
    return addedItem;
  }

  Future<void> reloadDocumentTypes() {
    return labelRepository.findAllDocumentTypes();
  }

  Future<DocumentType> replaceDocumentType(DocumentType item) async {
    assert(item.id != null);
    final updatedItem = await labelRepository.updateDocumentType(item);
    return updatedItem;
  }

  Future<void> removeDocumentType(DocumentType item) async {
    assert(item.id != null);
    if (labelRepository.documentTypes.containsKey(item.id)) {
      await labelRepository.deleteDocumentType(item);
    }
  }

  Future<StoragePath> addStoragePath(StoragePath item) async {
    assert(item.id == null);
    final addedItem = await labelRepository.createStoragePath(item);
    return addedItem;
  }

  Future<void> reloadStoragePaths() {
    return labelRepository.findAllStoragePaths();
  }

  Future<StoragePath> replaceStoragePath(StoragePath item) async {
    assert(item.id != null);
    final updatedItem = await labelRepository.updateStoragePath(item);
    return updatedItem;
  }

  Future<void> removeStoragePath(StoragePath item) async {
    assert(item.id != null);
    if (labelRepository.storagePaths.containsKey(item.id)) {
      await labelRepository.deleteStoragePath(item);
    }
  }

  Future<Tag> addTag(Tag item) async {
    assert(item.id == null);
    final addedItem = await labelRepository.createTag(item);
    return addedItem;
  }

  Future<void> reloadTags() {
    return labelRepository.findAllTags();
  }

  Future<Tag> replaceTag(Tag item) async {
    assert(item.id != null);
    final updatedItem = await labelRepository.updateTag(item);
    return updatedItem;
  }

  Future<void> removeTag(Tag item) async {
    assert(item.id != null);
    if (labelRepository.tags.containsKey(item.id)) {
      await labelRepository.deleteTag(item);
    }
  }

  @override
  Future<void> close() {
    labelRepository.removeListener(_updateStateListener);
    return super.close();
  }
}
