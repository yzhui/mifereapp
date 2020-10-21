
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';
import 'package:todo_app/Localization.dart';
import 'package:todo_app/Utils.dart';
import 'package:todo_app/domain/entity/Category.dart';
import 'package:todo_app/domain/entity/CategoryPicker.dart';
import 'package:todo_app/domain/entity/DayMemo.dart';
import 'package:todo_app/domain/entity/ToDo.dart';
import 'package:todo_app/domain/entity/ToDoRecord.dart';
import 'package:todo_app/domain/usecase/GetAllCategoriesUsecase.dart';
import 'package:todo_app/domain/usecase/GetDayRecordUsecase.dart';
import 'package:todo_app/domain/usecase/GetToDoRecordsUsecase.dart';
import 'package:todo_app/domain/usecase/GetUserCheckedToDoBeforeUsecase.dart';
import 'package:todo_app/domain/usecase/HasShownDayScreenTutorialUsecase.dart';
import 'package:todo_app/domain/usecase/IsDayMarkedCompletedUsecase.dart';
import 'package:todo_app/domain/usecase/RemoveCategoryUsecase.dart';
import 'package:todo_app/domain/usecase/RemoveToDoUsecase.dart';
import 'package:todo_app/domain/usecase/ScheduleReminderNotificationUsecase.dart';
import 'package:todo_app/domain/usecase/SetCategoryUsecase.dart';
import 'package:todo_app/domain/usecase/SetDayMemoUsecase.dart';
import 'package:todo_app/domain/usecase/SetShownDayScreenTutorialUsecase.dart';
import 'package:todo_app/domain/usecase/SetToDoRecordUsecase.dart';
import 'package:todo_app/domain/usecase/SetToDoUsecase.dart';
import 'package:todo_app/domain/usecase/SetUserCheckedToDoBeforeUsecase.dart';
import 'package:todo_app/domain/usecase/UnscheduleReminderNotificationUsecase.dart';
import 'package:todo_app/presentation/day/DayScreenTutorial.dart';
import 'package:todo_app/presentation/day/DayScreenTutorialCallback.dart';
import 'package:todo_app/presentation/day/DayState.dart';

class DayBloc {
  static const _oneDay = const Duration(days: 1);

  final _state = BehaviorSubject<DayState>.seeded(DayState());
  DayState getInitialState() => _state.value;
  Stream<DayState> observeState() => _state.distinct();

  final _getDayRecordUsecase = GetDayRecordUsecase();
  final _getToDoRecordsUsecase = GetToDoRecordsUsecase();
  final _setDayMemoUsecase = SetDayMemoUsecase();
  final _setToDoUsecase = SetToDoUsecase();
  final _setCategoryUsecase = SetCategoryUsecase();
  final _setToDoRecordUsecase = SetToDoRecordUsecase();
  final _removeToDoUsecase = RemoveToDoUsecase();
  final _getAllCategoriesUsecase = GetAllCategoriesUsecase();
  final _removeCategoryUsecase = RemoveCategoryUsecase();
  final _getUserCheckedToDoBeforeUsecase = GetUserCheckedToDoBeforeUsecase();
  final _setUserCheckedToDoBeforeUsecase = SetUserCheckedToDoBeforeUsecase();
  final _hasShownDayScreenTutorialUsecase = HasShownDayScreenTutorialUsecase();
  final _setShownDayScreenTutorialUsecase = SetShownDayScreenTutorialUsecase();
  final _isDayMarkedCompletedUsecase = IsDayMarkedCompletedUsecase();
  final _scheduleReminderNotificationUsecase = ScheduleReminderNotificationUsecase();
  final _unscheduleReminderNotificationUsecase = UnscheduleReminderNotificationUsecase();

  DayBloc(DateTime date) {
    _initState(date);
  }

  // initialDate is the date user clicked in WeekScreen to enter DayScreen
  Future<void> _initState(DateTime initialDate) async {
    final currentDate = initialDate;
    final currentDayRecord = await _getDayRecordUsecase.invoke(currentDate);
    final prevDayRecord = await _getDayRecordUsecase.invoke(currentDate.subtract(_oneDay));
    final nextDayRecord = await _getDayRecordUsecase.invoke(currentDate.add(_oneDay));
    final allCategories = await _getAllCategoriesUsecase.invoke();
    final startTutorial = !(await _hasShownDayScreenTutorialUsecase.invoke());

    final editingToDoRecord = _createDraftToDoRecord(currentDate, currentDayRecord.toDoRecords);
    final editingCategory = editingToDoRecord.category.buildNew();
    _state.add(_state.value.buildNew(
      viewState: DayViewState.NORMAL,
      editingToDoRecord: editingToDoRecord,
      editingCategory: editingCategory,
      allCategories: allCategories,
      currentDayRecord: currentDayRecord,
      prevDayRecord: prevDayRecord,
      nextDayRecord: nextDayRecord,
      initialDate: initialDate,
      currentDate: currentDate,
      pageViewScrollEnabled: !startTutorial,

      startTutorialEvent: startTutorial,
    ));
  }

  Future<void> onDayRecordPageIndexChanged(int newIndex) async {
    final currentDate = _state.value.initialDate.add(Duration(days: newIndex - _state.value.initialDayRecordPageIndex));

    // update date text first for smoother UI
    _state.add(_state.value.buildNew(
      currentDate: currentDate,
      currentDayRecordPageIndex: newIndex,
    ));

    final currentDayRecord = await _getDayRecordUsecase.invoke(currentDate);
    final prevDayRecord = await _getDayRecordUsecase.invoke(currentDate.subtract(_oneDay));
    final nextDayRecord = await _getDayRecordUsecase.invoke(currentDate.add(_oneDay));
    final editingToDoRecord = _createDraftToDoRecord(currentDate, currentDayRecord.toDoRecords);
    final editingCategory = editingToDoRecord.category.buildNew();

    _state.add(_state.value.buildNew(
      viewState: DayViewState.NORMAL,
      editorState: EditorState.HIDDEN,
      editingToDoRecord: editingToDoRecord,
      editingCategory: editingCategory,
      currentDayRecord: currentDayRecord,
      prevDayRecord: prevDayRecord,
      nextDayRecord: nextDayRecord,
      selectedToDoKeys: const [],
    ));
  }

  ToDoRecord _createDraftToDoRecord(DateTime date, List<ToDoRecord> currentRecords) {
    final nextOrder = currentRecords.isEmpty ? 0 : currentRecords.last.toDo.order + 1;
    return ToDoRecord.createDraft(date, nextOrder);
  }

  bool handleBackPress() {
    final viewState = _state.value.viewState;
    if (viewState == DayViewState.SELECTION) {
      _state.add(_state.value.buildNew(
        viewState: DayViewState.NORMAL,
        selectedToDoKeys: const [],
      ));
      return true;
    }

    final editorState = _state.value.editorState;
    if (editorState == EditorState.SHOWN_CATEGORY) {
      _state.add(_state.value.buildNew(
        editorState: EditorState.SHOWN_TODO,
      ));
      return true;
    } else if (editorState == EditorState.SHOWN_TODO) {
      _state.add(_state.value.buildNew(
        editorState: EditorState.HIDDEN,
      ));
      return true;
    }

    return false;
  }

  void onBackArrowClicked(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> onAddToDoClicked(BuildContext context, ScaffoldState scaffoldState) async {
    final isDayMarkedCompleted = await _isDayMarkedCompletedUsecase.invoke(_state.value.currentDate);
    if (isDayMarkedCompleted) {
      final msg = AppLocalizations.of(context).cannotModifyCompletedDaysTasks;
      Utils.showSnackBar(scaffoldState, msg, const Duration(seconds: 1));
      return;
    }

    final currentDayRecord = _state.value.currentDayRecord;
    final toDoRecords = currentDayRecord.toDoRecords;
    final draft = _createDraftToDoRecord(_state.value.currentDate, toDoRecords);
    final draftCategory = draft.category.buildNew();
    _state.add(_state.value.buildNew(
      editingToDoRecord: draft,
      editingCategory: draftCategory,
      editorState: EditorState.SHOWN_TODO,
      scrollToToDoListEvent: true,
    ));
  }

  void onDayMemoTextChanged(DayMemo dayMemo, String changed) {
    final updatedDayMemo = dayMemo.buildNew(text: changed);
    _state.add(_state.value.buildNewDayMemoUpdated(updatedDayMemo));
    _setDayMemoUsecase.invoke(updatedDayMemo);
  }

  Future<void> onToDoCheckBoxClicked(BuildContext context, ToDo toDo) async {
    final userCheckedToDoBefore = await _getUserCheckedToDoBeforeUsecase.invoke();
    if (!userCheckedToDoBefore) {
      final title = AppLocalizations.of(context).firstToDoCheckTitle;
      final body = AppLocalizations.of(context).firstToDoCheckBody;
      Utils.showAppDialog(context,
        title,
        body,
        null,
          () {
          _setUserCheckedToDoBeforeUsecase.invoke();
          _setToDoDone(toDo);
        }
      );
    } else {
      _setToDoDone(toDo);
    }
  }

  void _setToDoDone(ToDo toDo) {
    final updated = toDo.buildNew(isDone: true);
    _state.add(_state.value.buildNewToDoUpdated(updated));
    _setToDoUsecase.invoke(updated);

    final allToDosDone = _state.value.currentDayRecord.toDoRecords.every((it) => it.toDo.isDone);
    if (_state.value.currentDayRecord.isToday && allToDosDone) {
      _unscheduleReminderNotificationUsecase.invoke();
    }

    handleBackPress();
  }

  void onEditingCategoryTextChanged(String changed) {
    _state.add(_state.value.buildNew(
      editingCategory: _state.value.editingCategory.buildNew(name: changed),
    ));
  }

  void onEditingToDoTextChanged(String changed) {
    final currentEditingRecord = _state.value.editingToDoRecord;
    final updated = currentEditingRecord.buildNew(toDo: currentEditingRecord.toDo.buildNew(text: changed));
    _state.add(_state.value.buildNew(editingToDoRecord: updated));
  }

  Future<void> onToDoRecordItemClicked(BuildContext context, ToDoRecord toDoRecord, ScaffoldState scaffoldState) async {
    final isDayMarkedCompleted = await _isDayMarkedCompletedUsecase.invoke(_state.value.currentDate);
    if (isDayMarkedCompleted) {
      final msg = AppLocalizations.of(context).cannotModifyCompletedDaysTasks;
      Utils.showSnackBar(scaffoldState, msg, const Duration(seconds: 1));
      return;
    }

    if (_state.value.viewState == DayViewState.SELECTION) {
      final selectedKey = toDoRecord.toDo.key;
      final currentKeys = _state.value.selectedToDoKeys;
      if (currentKeys.contains(selectedKey)) {
        final newKeys = List.of(currentKeys);
        newKeys.remove(selectedKey);
        _state.add(_state.value.buildNew(
          selectedToDoKeys: newKeys,
        ));
      } else {
        final newKeys = List.of(currentKeys);
        newKeys.add(selectedKey);
        _state.add(_state.value.buildNew(
          selectedToDoKeys: newKeys,
        ));
      }
    } else {
      _state.add(_state.value.buildNew(
        editingToDoRecord: toDoRecord.buildNew(),
        editingCategory: toDoRecord.category.buildNew(),
        editorState: EditorState.SHOWN_TODO,
        scrollToToDoListEvent: true,
      ));
    }
  }

  Future<void> onToDoEditingDone(BuildContext context) async {
    if (_state.value.editingToDoRecord.toDo.text.length == 0) {
      return;
    }

    final editedRecord = _state.value.editingToDoRecord.buildNew(isDraft: false);
    await _setToDoRecordUsecase.invoke(editedRecord);

    final currentDayRecord = _state.value.currentDayRecord;
    final toDoRecords = await _getToDoRecordsUsecase.invoke(_state.value.currentDate);
    final updatedDayRecord = currentDayRecord.buildNew(toDoRecords: toDoRecords);

    final editingToDoRecord = _createDraftToDoRecord(_state.value.currentDate, toDoRecords)
      .buildNew(category: editedRecord.category);
    final editingCategory = editingToDoRecord.category.buildNew();

    _state.add(_state.value.buildNew(
      editingToDoRecord: editingToDoRecord,
      editingCategory: editingCategory,
      currentDayRecord: updatedDayRecord,
      scrollToBottomEvent: true,
    ));

    final newToDoAdded = currentDayRecord.toDoRecords.length != toDoRecords.length;
    if (currentDayRecord.isToday && newToDoAdded) {
      _scheduleReminderNotificationUsecase.invoke(context, _state.value.year, _state.value.month, _state.value.day);
    }
  }

  void onEditorCategoryButtonClicked() {
    _state.add(_state.value.buildNew(
      editingCategory: _state.value.editingToDoRecord.category.buildNew(),
      selectedPickerIndex: -1,
      editorState: EditorState.SHOWN_CATEGORY,
    ));
  }

  Future<void> onToDoRecordItemLongClicked(BuildContext context, ToDoRecord toDoRecord, ScaffoldState scaffoldState) async {
    final isDayMarkedCompleted = await _isDayMarkedCompletedUsecase.invoke(_state.value.currentDate);
    if (isDayMarkedCompleted) {
      final msg = AppLocalizations.of(context).cannotModifyCompletedDaysTasks;
      Utils.showSnackBar(scaffoldState, msg, const Duration(seconds: 1));
      return;
    }

    if (_state.value.viewState != DayViewState.SELECTION) {
      _state.add(_state.value.buildNew(
        viewState: DayViewState.SELECTION,
        selectedToDoKeys: [toDoRecord.toDo.key],
        editorState: EditorState.HIDDEN,
      ));
    }
  }

  void onCloseSelectionModeClicked() {
    handleBackPress();
  }

  void onRemoveSelectedToDosClicked(BuildContext context) {
    final selectedCount = _state.value.selectedToDoKeys.length;
    if (selectedCount > 0) {
      Utils.showAppDialog(context,
        AppLocalizations.of(context).removeSelectedToDosTitle,
        AppLocalizations.of(context).getRemoveSelectedToDosBody(selectedCount),
        null,
          () => _onRemoveSelectedToDosOkClicked());
    }
  }

  void onMoveUpSelectedToDosClicked() {
    final currentDayRecord = _state.value.currentDayRecord;
    final newToDoRecords = List.of(currentDayRecord.toDoRecords);
    final newSelectedToDoKeys = List.of(_state.value.selectedToDoKeys);
    if (newToDoRecords.length > 1 && newSelectedToDoKeys.length > 0) {
      for (int i = 0; i < newToDoRecords.length - 1; i++) {
        final currentRecord = newToDoRecords[i];
        final nextRecord = newToDoRecords[i + 1];
        final currentToDoKey = currentRecord.toDo.key;
        final nextToDoKey = nextRecord.toDo.key;
        if (!newSelectedToDoKeys.contains(currentToDoKey) && newSelectedToDoKeys.contains(nextToDoKey)) {
          final changedCurrentRecord = currentRecord.buildNew(toDo: currentRecord.toDo.buildNew(order: nextRecord.toDo.order));
          final changedNextRecord = nextRecord.buildNew(toDo: nextRecord.toDo.buildNew(order: currentRecord.toDo.order));

          newToDoRecords[i] = changedNextRecord;
          newToDoRecords[i + 1] = changedCurrentRecord;

          newSelectedToDoKeys.remove(nextToDoKey);
          newSelectedToDoKeys.add(changedNextRecord.toDo.key);
        }
      }

      _state.add(_state.value.buildNew(
        currentDayRecord: currentDayRecord.buildNew(toDoRecords: newToDoRecords),
        selectedToDoKeys: newSelectedToDoKeys,
      ));

      for (ToDoRecord record in newToDoRecords) {
        _setToDoRecordUsecase.invoke(record);
      }
    }
  }

  void onMoveDownSelectedToDosClicked() {
    final currentDayRecord = _state.value.currentDayRecord;
    final newToDoRecords = List.of(currentDayRecord.toDoRecords);
    final newSelectedToDoKeys = List.of(_state.value.selectedToDoKeys);
    if (newToDoRecords.length > 1 && newSelectedToDoKeys.length > 0) {
      for (int i = newToDoRecords.length - 1; i > 0; i--) {
        final currentRecord = newToDoRecords[i];
        final prevRecord = newToDoRecords[i - 1];
        final currentToDoKey = currentRecord.toDo.key;
        final prevToDoKey = prevRecord.toDo.key;
        if (!newSelectedToDoKeys.contains(currentToDoKey) && newSelectedToDoKeys.contains(prevToDoKey)) {
          final changedCurrentRecord = currentRecord.buildNew(toDo: currentRecord.toDo.buildNew(order: prevRecord.toDo.order));
          final changedPrevRecord = prevRecord.buildNew(toDo: prevRecord.toDo.buildNew(order: currentRecord.toDo.order));

          newToDoRecords[i] = changedPrevRecord;
          newToDoRecords[i - 1] = changedCurrentRecord;

          newSelectedToDoKeys.remove(prevToDoKey);
          newSelectedToDoKeys.add(changedPrevRecord.toDo.key);
        }
      }

      _state.add(_state.value.buildNew(
        currentDayRecord: currentDayRecord.buildNew(toDoRecords: newToDoRecords),
        selectedToDoKeys: newSelectedToDoKeys,
      ));

      for (ToDoRecord record in newToDoRecords) {
        _setToDoRecordUsecase.invoke(record);
      }
    }
  }

  void _onRemoveSelectedToDosOkClicked() {
    final keys = _state.value.selectedToDoKeys;
    final currentDayRecord = _state.value.currentDayRecord;
    final toDoRecords = currentDayRecord.toDoRecords;
    final removingRecords = toDoRecords.where((it) => keys.contains(it.toDo.key));

    final newRecords = List.of(toDoRecords);
    for (ToDoRecord removingRecord in removingRecords) {
      newRecords.remove(removingRecord);
      _removeToDoUsecase.invoke(removingRecord.toDo);
    }

    _state.add(_state.value.buildNew(
      selectedToDoKeys: const [],
      currentDayRecord: currentDayRecord.buildNew(toDoRecords: newRecords),
    ));

    final allToDosDone = newRecords.every((it) => it.toDo.isDone);
    if (allToDosDone) {
      _unscheduleReminderNotificationUsecase.invoke();
    }
  }

  void onCategoryEditorCategoryClicked(Category category) {
    final recordWithNewCategory = _state.value.editingToDoRecord.buildNew(category: category);
    _state.add(_state.value.buildNew(
      editingToDoRecord: recordWithNewCategory,
      editingCategory: category,
      editorState: EditorState.SHOWN_TODO,
    ));
  }

  Future<void> onChoosePhotoClicked() async {
    final imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
    final updatedCategory = _state.value.editingCategory.buildNew(
      fillColor: Category.COLOR_INVALID,
      borderColor: Category.COLOR_INVALID,
      imagePath: imageFile.path,
    );
    _state.add(_state.value.buildNew(
      editingCategory: updatedCategory,
      selectedPickerIndex: -1,
    ));
  }

  void onCategoryPickerSelected(CategoryPicker item) {
    final updatedCategory = item.isFillType ? _state.value.editingCategory.buildNew(
      fillColor: item.color,
      borderColor: Category.COLOR_INVALID,
      imagePath: '',
    ) : _state.value.editingCategory.buildNew(
      fillColor: Category.COLOR_INVALID,
      borderColor: item.color,
      imagePath: '',
    );
    final index = _state.value.categoryPickers.indexWhere((it) => it == item);
    _state.add(_state.value.buildNew(
      editingCategory: updatedCategory,
      selectedPickerIndex: index,
    ));
  }

  Future<void> onCreateNewCategoryClicked() async {
    final newCategoryId = await _setCategoryUsecase.invoke(_state.value.editingCategory.buildNew(id: Category.ID_NEW));
    final newCategory = _state.value.editingCategory.buildNew(id: newCategoryId);
    final recordWithNewCategory = _state.value.editingToDoRecord.buildNew(category: newCategory);

    final allCategories = await _getAllCategoriesUsecase.invoke();

    _state.add(_state.value.buildNew(
      editingToDoRecord: recordWithNewCategory,
      editingCategory: newCategory,
      editorState: EditorState.SHOWN_TODO,
      allCategories: allCategories,
    ));
  }

  Future<void> onModifyCategoryClicked() async {
    final modifiedCategory = _state.value.editingCategory;
    final recordWithNewCategory = _state.value.editingToDoRecord.buildNew(category: modifiedCategory);

    await _setCategoryUsecase.invoke(modifiedCategory);
    final currentDayRecord = _state.value.currentDayRecord;
    final toDoRecords = await _getToDoRecordsUsecase.invoke(_state.value.currentDate);
    final updatedDayRecord = currentDayRecord.buildNew(toDoRecords: toDoRecords);
    final allCategories = await _getAllCategoriesUsecase.invoke();

    _state.add(_state.value.buildNew(
      editingToDoRecord: recordWithNewCategory,
      editorState: EditorState.SHOWN_TODO,
      allCategories: allCategories,
      currentDayRecord: updatedDayRecord,
    ));
  }

  void onCategoryEditorCategoryLongClicked(BuildContext context, Category category) {
    if (category.id == Category.ID_DEFAULT) {
      return;
    }

    Utils.showAppDialog(context,
      AppLocalizations.of(context).removeCategory,
      AppLocalizations.of(context).removeCategoryBody,
      null,
        () => _onRemoveCategoryOkClicked(context, category));
  }

  Future<void> _onRemoveCategoryOkClicked(BuildContext context, Category category) async {
    await _removeCategoryUsecase.invoke(category);
    final currentDayRecord = _state.value.currentDayRecord;
    final toDoRecords = await _getToDoRecordsUsecase.invoke(_state.value.currentDate);
    final updatedDayRecord = currentDayRecord.buildNew(toDoRecords: toDoRecords);
    final allCategories = await _getAllCategoriesUsecase.invoke();
    _state.add(_state.value.buildNew(
      allCategories: allCategories,
      currentDayRecord: updatedDayRecord,
    ));
  }

  void onNextArrowClicked() {
    final newPageIndex = _state.value.currentDayRecordPageIndex + 1;
    _state.add(_state.value.buildNew(
      currentDayRecordPageIndex: newPageIndex,
      animateToPageEvent: newPageIndex,
    ));
  }

  void onPrevArrowClicked() {
    final newPageIndex = _state.value.currentDayRecordPageIndex - 1;
    _state.add(_state.value.buildNew(
      currentDayRecordPageIndex: newPageIndex,
      animateToPageEvent: newPageIndex,
    ));
  }

  void onBackFABClicked(BuildContext context) {
    Navigator.pop(context);
  }

  void onToDoEditorCancelClicked() {
    handleBackPress();
  }

  Future<void> startTutorial(BuildContext context, DayScreenTutorialCallback callback) async {
    _state.add(_state.value.buildNew(
      fabsSlideAnimationEvent: DayState.FABS_SLIDE_ANIMTION_UP,
    ));

    final result = await Navigator.push(context, PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, _, __) => DayScreenTutorial(
        dayScreenTutorialCallback: callback,
      ),
    ));
    if (result == -1) {
      Navigator.pop(context);
    } else {
      _setShownDayScreenTutorialUsecase.invoke();
      _state.add(_state.value.buildNew(
        pageViewScrollEnabled: true,
        fabsSlideAnimationEvent: DayState.FABS_SLIDE_ANIMTION_DOWN,
      ));
    }
  }

  void onCategoryEditorCancelClicked() {
    handleBackPress();
  }
}