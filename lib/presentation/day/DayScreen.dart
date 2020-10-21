
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:todo_app/AppColors.dart';
import 'package:todo_app/Localization.dart';
import 'package:todo_app/domain/entity/Category.dart';
import 'package:todo_app/domain/entity/CategoryPicker.dart';
import 'package:todo_app/domain/entity/DayMemo.dart';
import 'package:todo_app/domain/entity/DayRecord.dart';
import 'package:todo_app/domain/entity/ToDoRecord.dart';
import 'package:todo_app/domain/entity/ViewLayoutInfo.dart';
import 'package:todo_app/presentation/day/DayBloc.dart';
import 'package:todo_app/presentation/day/DayScreenTutorialCallback.dart';
import 'package:todo_app/presentation/day/DayState.dart';
import 'package:todo_app/presentation/widgets/AppTextField.dart';

class DayScreen extends StatefulWidget {
  static const MAX_DAY_PAGE = 100;
  static const INITIAL_DAY_PAGE = 50;

  final DateTime date;

  DayScreen(this.date);

  @override
  State createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> with SingleTickerProviderStateMixin implements DayScreenTutorialCallback {
  DayBloc _bloc;
  ScrollController _toDoScrollController;
  final Map<String, FocusNode> _focusNodes = {};
  PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final GlobalKey<_HeaderShadowState> _headerShadowKey = GlobalKey();

  // variables related with tutorial
  AnimationController _fabsSlideUpController;
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _firstMemoKey = GlobalKey();
  final GlobalKey _addToDoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bloc = DayBloc(widget.date);
    _toDoScrollController = ScrollController();
    _pageController = PageController(initialPage: _bloc.getInitialState().initialDayRecordPageIndex);

    _fabsSlideUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _toDoScrollController.dispose();
    _pageController.dispose();

    _focusNodes.forEach((key, focusNode) => focusNode.dispose());
    _focusNodes.clear();

    _fabsSlideUpController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      initialData: _bloc.getInitialState(),
      stream: _bloc.observeState(),
      builder: (context, snapshot) {
        return _buildUI(snapshot.data);
      }
    );
  }

  Widget _buildUI(DayState state) {
    if (state.scrollToBottomEvent) {
      SchedulerBinding.instance.addPostFrameCallback((duration) {
        if (_toDoScrollController.hasClients) {
          _toDoScrollController.position.jumpTo(
            _toDoScrollController.position.maxScrollExtent,
          );
        }
      });
    }

    if (state.scrollToToDoListEvent) {
      // 500.. magic number..
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_toDoScrollController.hasClients) {
          final double targetPixel = 170;
          if (_toDoScrollController.position.pixels < targetPixel) {
            _toDoScrollController.position.animateTo(
              targetPixel,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }

    if (state.animateToPageEvent != -1) {
      SchedulerBinding.instance.addPostFrameCallback((duration) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(state.animateToPageEvent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.ease,
          );
        }
      });
    }

    if (state.startTutorialEvent) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _checkViewsBuiltToStartTutorial());
    }

    if (state.fabsSlideAnimationEvent == DayState.FABS_SLIDE_ANIMTION_UP) {
      _fabsSlideUpController.forward();
    } else if (state.fabsSlideAnimationEvent == DayState.FABS_SLIDE_ANIMTION_DOWN) {
      _fabsSlideUpController.reverse();
    }

    final isSelectionMode = state.viewState == DayViewState.SELECTION;
    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: state.viewState == DayViewState.WHOLE_LOADING ? _WholeLoadingView()
          : WillPopScope(
          onWillPop: () async => !_bloc.handleBackPress() && !_unfocusTextFieldIfAny(),
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _Header(
                    key: _headerKey,
                    bloc: _bloc,
                    title: isSelectionMode ? state.selectedToDoKeys.length.toString()
                      : AppLocalizations.of(context).getDayScreenTitle(state.month, state.day, state.weekday),
                    isSelectionMode: isSelectionMode,
                    pageViewScrollEnabled: state.pageViewScrollEnabled,
                  ),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        PageView.builder(
                          physics: state.pageViewScrollEnabled ? PageScrollPhysics() : NeverScrollableScrollPhysics(),
                          controller: _pageController,
                          itemCount: DayScreen.MAX_DAY_PAGE,
                          itemBuilder: (context, index) {
                            final dayRecord = state.getDayRecordForPageIndex(index);
                            if (dayRecord == null) {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            } else {
                              return _DayRecord(
                                bloc: _bloc,
                                dayRecord: dayRecord,
                                focusNodeProvider: _getOrCreateFocusNode,
                                scrollController: _toDoScrollController,
                                isSelectionMode: isSelectionMode,
                                selectedToDoKeys: state.selectedToDoKeys,
                                memoKey: index == DayScreen.INITIAL_DAY_PAGE ? _firstMemoKey : null,
                                scaffoldState: _scaffoldKey.currentState,
                              );
                            }
                          },
                          onPageChanged: (changedIndex) {
                            _unfocusTextFieldIfAny();
                            _headerShadowKey.currentState.updateShadowVisibility(false);
                            _bloc.onDayRecordPageIndexChanged(changedIndex);
                          },
                        ),
                        _HeaderShadow(
                          key: _headerShadowKey,
                          scrollController: _toDoScrollController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // editor positioned just above the keyboard
              state.editorState == EditorState.HIDDEN ? const SizedBox.shrink()
                : state.editorState == EditorState.SHOWN_TODO ? _ToDoEditorContainer(
                bloc: _bloc,
                editingToDoRecord: state.editingToDoRecord,
                focusNodeProvider: _getOrCreateFocusNode,
              ) : _CategoryEditorContainer(
                bloc: _bloc,
                allCategories: state.allCategories,
                editingCategory: state.editingCategory,
                categoryPickers: state.categoryPickers,
                selectedPickerIndex: state.selectedPickerIndex,
                focusNodeProvider: _getOrCreateFocusNode,
              ),
              state.isFabVisible ? _AddToDoFAB(
                bloc: _bloc,
                fabKey: _addToDoKey,
                slideUpController: _fabsSlideUpController,
                scaffoldState: _scaffoldKey.currentState,
              ) : const SizedBox.shrink(),
              state.isFabVisible ? _BackFAB(
                bloc: _bloc,
                slideUpController: _fabsSlideUpController,
              ) : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  void _checkViewsBuiltToStartTutorial() {
    // check for one element. Simple checking.
    if (_firstMemoKey.currentContext?.findRenderObject() == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _checkViewsBuiltToStartTutorial());
      return;
    }

    _bloc.startTutorial(context, this);
  }

  FocusNode _getOrCreateFocusNode(String key) {
    if (_focusNodes.containsKey(key)) {
      return _focusNodes[key];
    } else {
      final newFocusNode = FocusNode();
      _focusNodes[key] = newFocusNode;
      return newFocusNode;
    }
  }

  bool _unfocusTextFieldIfAny() {
    for (FocusNode focusNode in _focusNodes.values) {
      if (focusNode.hasPrimaryFocus) {
        focusNode.unfocus();
        return true;
      }
    }
    return false;
  }

  @override
  ViewLayoutInfo Function() getHeaderFinder() {
    return () {
      final RenderBox box = _headerKey.currentContext?.findRenderObject();
      return ViewLayoutInfo.create(box);
    };
  }

  @override
 ViewLayoutInfo Function() getMemoFinder() {
    return () {
      final RenderBox box = _firstMemoKey.currentContext?.findRenderObject();
      return ViewLayoutInfo.create(box);
    };
  }

  @override
  ViewLayoutInfo Function() getAddToDoFinder() {
    return () {
      final RenderBox box = _addToDoKey.currentContext?.findRenderObject();
      return ViewLayoutInfo.create(box);
    };
  }
}

class _WholeLoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.BACKGROUND_WHITE,
      alignment: Alignment.center,
      child: CircularProgressIndicator(),
    );
  }
}

class _DayRecord extends StatelessWidget {
  final DayBloc bloc;
  final DayRecord dayRecord;
  final FocusNode Function(String key) focusNodeProvider;
  final ScrollController scrollController;
  final bool isSelectionMode;
  final List<String> selectedToDoKeys;
  final Key memoKey;
  final ScaffoldState scaffoldState;

  _DayRecord({
    @required this.bloc,
    @required this.dayRecord,
    @required this.focusNodeProvider,
    @required this.scrollController,
    @required this.isSelectionMode,
    @required this.selectedToDoKeys,
    @required this.memoKey,
    @required this.scaffoldState,
  });

  @override
  Widget build(BuildContext context) {
    final dayRecord = this.dayRecord;
    final dayMemo = dayRecord.isToday ? dayRecord.dayMemo.buildNew(hint: AppLocalizations.of(context).dayMemoHint)
      : dayRecord.dayMemo;
    final dayMemoWidget = _DayMemo(
      bloc: bloc,
      dayMemo: dayMemo,
      focusNodeProvider: focusNodeProvider,
      isInSelectionMode: isSelectionMode,
      memoKey: memoKey,
    );

    return dayRecord.toDoRecords.length == 0 ? _EmptyToDoListView(
      bloc: bloc,
      dayMemoWidget: dayMemoWidget,
      focusNodeProvider: focusNodeProvider,
    ) : _ToDoListView(
      bloc: bloc,
      dayMemoWidget: dayMemoWidget,
      toDoRecords: dayRecord.toDoRecords,
      scrollController: scrollController,
      focusNodeProvider: focusNodeProvider,
      isSelectionMode: isSelectionMode,
      selectedToDoKeys: selectedToDoKeys,
      scaffoldState: scaffoldState,
    );
  }
}

class _AddToDoFAB extends StatelessWidget {
  final DayBloc bloc;
  final Key fabKey;
  final Animation slideUpController;
  final ScaffoldState scaffoldState;

  _AddToDoFAB({
    @required this.bloc,
    @required this.fabKey,
    @required this.slideUpController,
    @required this.scaffoldState,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16,),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset(0, 0), end: Offset(0, -1)).animate(CurvedAnimation(
            parent: slideUpController,
            curve: Curves.ease,
          )),
          child: FloatingActionButton(
            key: fabKey,
            child: Image.asset('assets/ic_plus.png'),
            backgroundColor: AppColors.PRIMARY,
            splashColor: AppColors.PRIMARY_DARK,
            onPressed: () => bloc.onAddToDoClicked(context, scaffoldState),
          ),
        ),
      ),
    );
  }
}

class _BackFAB extends StatelessWidget {
  final DayBloc bloc;
  final Animation slideUpController;

  _BackFAB({
    @required this.bloc,
    @required this.slideUpController,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 16,),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset(0, 0), end: Offset(0, -1)).animate(CurvedAnimation(
            parent: slideUpController,
            curve: Curves.ease,
          )),
          child: FloatingActionButton(
            heroTag: null,
            child: Image.asset('assets/ic_back_arrow.png'),
            backgroundColor: AppColors.BACKGROUND_WHITE,
            onPressed: () => bloc.onBackFABClicked(context),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DayBloc bloc;
  final String title;
  final bool isSelectionMode;
  final bool pageViewScrollEnabled;

  _Header({
    Key key,
    @required this.bloc,
    @required this.title,
    @required this.isSelectionMode,
    @required this.pageViewScrollEnabled,
  }): super(key: key);

  @override
  Widget build(BuildContext context) {
    return isSelectionMode ? Row(
      children: <Widget>[
        SizedBox(width: 4,),
        InkWell(
          onTap: () => bloc.onCloseSelectionModeClicked(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/ic_close_black.png'),
          ),
        ),
        SizedBox(width: 2,),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14,),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                color: AppColors.TEXT_BLACK,
              ),
              strutStyle: StrutStyle(
                fontSize: 24,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: isSelectionMode ? TextAlign.start : TextAlign.center,
            ),
          ),
        ),
        Spacer(),
        InkWell(
          onTap: () => bloc.onMoveUpSelectedToDosClicked(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset('assets/ic_up.png'),
          ),
        ),
        InkWell(
          onTap: () => bloc.onMoveDownSelectedToDosClicked(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset('assets/ic_down.png'),
          ),
        ),
        InkWell(
          onTap: () => bloc.onRemoveSelectedToDosClicked(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset('assets/ic_trash.png'),
          ),
        ),
        SizedBox(width: 12,),
      ],
    ): Row(
      children: <Widget>[
        SizedBox(width: 4,),
        InkWell(
          onTap: pageViewScrollEnabled ? () => bloc.onPrevArrowClicked() : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/ic_prev.png'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14,),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                color: AppColors.TEXT_BLACK,
              ),
              strutStyle: StrutStyle(
                fontSize: 24,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        InkWell(
          onTap: pageViewScrollEnabled ? () => bloc.onNextArrowClicked() : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/ic_next.png'),
          ),
        ),
        SizedBox(width: 4,),
      ],
    );
  }
}

class _EmptyToDoListView extends StatelessWidget {
  final DayBloc bloc;
  final Widget dayMemoWidget;
  final FocusNode Function(String key) focusNodeProvider;

  _EmptyToDoListView({
    @required this.bloc,
    @required this.dayMemoWidget,
    @required this.focusNodeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        dayMemoWidget,
        Padding(
          padding: EdgeInsets.only(left: 36, top: 20),
          child: Text(
            'TODO',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.TEXT_BLACK,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              AppLocalizations.of(context).noToDos,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.TEXT_BLACK_LIGHT,
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _DayMemo extends StatelessWidget {
  final DayBloc bloc;
  final DayMemo dayMemo;
  final FocusNode Function(String key) focusNodeProvider;
  final bool isInSelectionMode;
  final Key memoKey;

  _DayMemo({
    @required this.bloc,
    @required this.dayMemo,
    @required this.focusNodeProvider,
    @required this.isInSelectionMode,
    @required this.memoKey,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = dayMemo.isExpanded;
    return Padding(
      padding: EdgeInsets.only(left: 24, top: 12, right: 24),
      child: DecoratedBox(
        key: memoKey,
        decoration: BoxDecoration(
          color: AppColors.PRIMARY,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'MEMO',
                style: TextStyle(
                  color: AppColors.TEXT_WHITE,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            isExpanded ? Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: SizedBox(
                height: 97,
                child: AppTextField(
                  focusNode: focusNodeProvider(dayMemo.key),
                  text: dayMemo.text,
                  textSize: 14,
                  textColor: AppColors.TEXT_WHITE,
                  hintText: dayMemo.hint,
                  hintTextSize: 14,
                  hintColor: AppColors.TEXT_WHITE_DARK,
                  onChanged: (s) => bloc.onDayMemoTextChanged(dayMemo, s),
                  maxLines: null,
                  cursorColor: AppColors.TEXT_WHITE,
                  enabled: !isInSelectionMode,
                ),
              ),
            ) : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _ToDoListView extends StatelessWidget {
  final DayBloc bloc;
  final Widget dayMemoWidget;
  final List<ToDoRecord> toDoRecords;
  final ScrollController scrollController;
  final FocusNode Function(String key) focusNodeProvider;
  final bool isSelectionMode;
  final List<String> selectedToDoKeys;
  final ScaffoldState scaffoldState;

  _ToDoListView({
    @required this.bloc,
    @required this.dayMemoWidget,
    @required this.toDoRecords,
    @required this.scrollController,
    @required this.focusNodeProvider,
    @required this.isSelectionMode,
    @required this.selectedToDoKeys,
    @required this.scaffoldState,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: toDoRecords.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return dayMemoWidget;
        } else if (index == 1) {
          return Padding(
            padding: EdgeInsets.only(left: 36, top: 20, bottom: 12),
            child: Text(
              'TODO',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.TEXT_BLACK,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          final realIndex = index - 2;
          return _ToDoItem(
            bloc: bloc,
            toDoRecord: toDoRecords[realIndex],
            isLast: realIndex == toDoRecords.length - 1,
            isSelectionMode: isSelectionMode,
            isSelectedInSelectionMode: selectedToDoKeys.contains(toDoRecords[realIndex].toDo.key),
            scaffoldState: scaffoldState,
          );
        }
      },
    );
  }
}

class _ToDoItem extends StatelessWidget {
  final DayBloc bloc;
  final ToDoRecord toDoRecord;
  final bool isLast;
  final bool isSelectionMode;
  final bool isSelectedInSelectionMode;
  final ScaffoldState scaffoldState;

  _ToDoItem({
    @required this.bloc,
    @required this.toDoRecord,
    @required this.isLast,
    @required this.isSelectionMode,
    @required this.isSelectedInSelectionMode,
    @required this.scaffoldState,
  });

  @override
  Widget build(BuildContext context) {
    final toDo = toDoRecord.toDo;
    final category = toDoRecord.category;
    return Column(
      children: <Widget>[
        _ToDoItemDivider(),
        Container(
          color: isSelectedInSelectionMode ? AppColors.BACKGROUND_GREY_LIGHT : Colors.transparent,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              child: Row(
                children: <Widget>[
                  SizedBox(width: 36,),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _CategoryThumbnail(
                      category: category,
                      width: 36,
                      height: 36,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(width: 36),
                  Expanded(
                    child: category.id == Category.ID_DEFAULT ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        toDo.text,
                        style: toDo.isDone ? TextStyle(
                          fontSize: 14,
                          color: AppColors.TEXT_BLACK_LIGHT,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.TEXT_BLACK_LIGHT,
                          decorationThickness: 2,
                        ) : TextStyle(
                          fontSize: 14,
                          color: AppColors.TEXT_BLACK,
                        ),
                      ),
                    ) : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            toDo.text,
                            style: toDo.isDone ? TextStyle(
                              fontSize: 14,
                              color: AppColors.TEXT_BLACK_LIGHT,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.TEXT_BLACK_LIGHT,
                              decorationThickness: 2,
                            ) : TextStyle(
                              fontSize: 14,
                              color: AppColors.TEXT_BLACK,
                            ),
                          ),
                          SizedBox(height: 2,),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.TEXT_BLACK_LIGHT,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  isSelectionMode ? Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, top: 14, right: 14, bottom: 14),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.TEXT_BLACK_LIGHT,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isSelectedInSelectionMode ? Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.PRIMARY,
                            ),
                          ): const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ) : toDo.isDone ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 39),
                    child: Image.asset('assets/ic_check.png'),
                  ) : Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: InkWell(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, top: 14, right: 14, bottom: 14),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.TEXT_BLACK_LIGHT,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                      customBorder: CircleBorder(),
                      onTap: () => bloc.onToDoCheckBoxClicked(context, toDo),
                    ),
                  ),
                ],
              ),
              onTap: () => bloc.onToDoRecordItemClicked(context, toDoRecord, scaffoldState),
              onLongPress: () => bloc.onToDoRecordItemLongClicked(context, toDoRecord, scaffoldState),
            ),
          ),
        ),
        isLast ? _ToDoItemDivider() : const SizedBox.shrink(),
        isLast ? const SizedBox(height: 96) : const SizedBox.shrink(),
      ],
    );
  }
}

class _ToDoItemDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 1,
        color: AppColors.DIVIDER,
      ),
    );
  }
}

class _CategoryThumbnail extends StatelessWidget {
  final Category category;
  final double width;
  final double height;
  final double fontSize;

  _CategoryThumbnail({
    @required this.category,
    @required this.width,
    @required this.height,
    @required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final type = category.thumbnailType;
    switch (type) {
      case CategoryThumbnailType.IMAGE:
        return _ImageCategoryThumbnail(
          imagePath: category.imagePath,
          width: width,
          height: height
        );
      default:
        return _ColorCategoryThumbnail(
          fillColor: category.fillColor,
          borderColor: category.borderColor,
          initial: category.initial,
          width: width,
          height: height,
          fontSize: fontSize,
        );
    }
  }
}

class _ImageCategoryThumbnail extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;

  _ImageCategoryThumbnail({
    @required this.imagePath,
    @required this.width,
    @required this.height
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          fit: BoxFit.cover,
          image: FileImage(File(imagePath)),
        )
      ),
    );
  }
}

class _ColorCategoryThumbnail extends StatelessWidget {
  final Color fillColor;
  final Color borderColor;
  final String initial;
  final double width;
  final double height;
  final double fontSize;

  _ColorCategoryThumbnail({
    @required this.fillColor,
    @required this.borderColor,
    @required this.initial,
    @required this.width,
    @required this.height,
    @required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isFill = fillColor != Category.COLOR_INVALID;
    return Container(
      width: width,
      height: height,
      decoration: isFill ? BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
      ) : BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: fontSize,
            color: isFill ? AppColors.TEXT_WHITE : AppColors.TEXT_BLACK,
          ),
          textScaleFactor: 1.0,
        ),
      ),
    );
  }
}

class _ToDoEditorContainer extends StatelessWidget {
  final DayBloc bloc;
  final ToDoRecord editingToDoRecord;
  final FocusNode Function(String key) focusNodeProvider;

  _ToDoEditorContainer({
    @required this.bloc,
    @required this.editingToDoRecord,
    @required this.focusNodeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.DIVIDER, AppColors.DIVIDER.withAlpha(0)]
              )
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.DIVIDER,
          ),
          Container(
            color: AppColors.BACKGROUND_WHITE,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ToDoEditor(
                  bloc: bloc,
                  editingToDoRecord: editingToDoRecord,
                  focusNodeProvider: focusNodeProvider,
                ),
                SizedBox(height: 2,),
                Row(
                  children: <Widget>[
                    _ToDoEditorCategoryButton(
                      bloc: bloc,
                      categoryName: editingToDoRecord.category.name,
                    ),
                    Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 10,),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14,),
                            child: Text(
                              AppLocalizations.of(context).cancel,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.SECONDARY,
                              ),
                            ),
                          ),
                          onTap: () => bloc.onToDoEditorCancelClicked(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ToDoEditor extends StatelessWidget {
  static const _focusNodeKey = 'toDoEditor';

  final DayBloc bloc;
  final ToDoRecord editingToDoRecord;
  final FocusNode _focusNode;

  _ToDoEditor({
    @required this.bloc,
    @required this.editingToDoRecord,
    @required FocusNode Function(String key) focusNodeProvider,
  }): _focusNode = focusNodeProvider(_focusNodeKey);

  @override
  StatelessElement createElement() {
    SchedulerBinding.instance.addPostFrameCallback((duration) {
      _focusNode.requestFocus();
    });
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    final category = editingToDoRecord.category;
    final toDo = editingToDoRecord.toDo;
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 10,),
      child: Row(
        children: <Widget>[
          _CategoryThumbnail(
            category: category,
            width: 24,
            height: 24,
            fontSize: 14,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4,),
              child: AppTextField(
                focusNode: _focusNode,
                text: toDo.text,
                textSize: 14,
                textColor: AppColors.TEXT_BLACK,
                hintText: editingToDoRecord.isDraft ? AppLocalizations.of(context).addTask : AppLocalizations.of(context).modifyTask,
                hintTextSize: 14,
                hintColor: AppColors.TEXT_BLACK_LIGHT,
                onChanged: (s) => bloc.onEditingToDoTextChanged(s),
                onEditingComplete: () => bloc.onToDoEditingDone(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10,),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14,),
                  child: Text(
                    editingToDoRecord.isDraft ? AppLocalizations.of(context).add : AppLocalizations.of(context).modify,
                    style: TextStyle(
                      fontSize: 14,
                      color: toDo.text.length > 0 ? AppColors.PRIMARY : AppColors.TEXT_BLACK_LIGHT,
                    ),
                  ),
                ),
                onTap: () => bloc.onToDoEditingDone(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToDoEditorCategoryButton extends StatelessWidget {
  final DayBloc bloc;
  final String categoryName;

  _ToDoEditorCategoryButton({
    @required this.bloc,
    @required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => bloc.onEditorCategoryButtonClicked(),
        child: Container(
          padding: const EdgeInsets.all(5),
          constraints: BoxConstraints(
            maxWidth: 200,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            color: AppColors.PRIMARY,
          ),
          child: Text(
            '${AppLocalizations.of(context).category}: '
              '${categoryName.isEmpty ? AppLocalizations.of(context).categoryNone : categoryName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.TEXT_WHITE,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditorContainer extends StatelessWidget {
  final DayBloc bloc;
  final List<Category> allCategories;
  final Category editingCategory;
  final List<CategoryPicker> categoryPickers;
  final int selectedPickerIndex;
  final FocusNode Function(String key) focusNodeProvider;

  _CategoryEditorContainer({
    @required this.bloc,
    @required this.allCategories,
    @required this.editingCategory,
    @required this.categoryPickers,
    @required this.selectedPickerIndex,
    @required this.focusNodeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          color: AppColors.SCRIM,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: AppColors.BACKGROUND_WHITE,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _CategoryEditorCategoryList(
                  bloc: bloc,
                  allCategories: allCategories,
                ),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: AppColors.DIVIDER_DARK,
                ),
                Column(
                  children: <Widget>[
                    _CategoryEditor(
                      bloc: bloc,
                      category: editingCategory,
                      focusNodeProvider: focusNodeProvider,
                    ),
                    SizedBox(height: 2,),
                    Row(
                      children: <Widget>[
                        _ChoosePhotoButton(
                          bloc: bloc,
                        ),
                        SizedBox(width: 10,),
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ListView.builder(
                              itemCount: categoryPickers.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final categoryPicker = categoryPickers[index];
                                return _CategoryPickerItem(
                                  bloc: bloc,
                                  item: categoryPicker,
                                  isSelected: index == selectedPickerIndex,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 3,),
                        Material(
                          child: InkWell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14,),
                              child: Text(
                                AppLocalizations.of(context).cancel,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.SECONDARY,
                                ),
                              ),
                            ),
                            onTap: () => bloc.onCategoryEditorCancelClicked(),
                          ),
                        ),
                        SizedBox(width: 10,),
                      ],
                    ),
                  ],
                )
              ],
            ),
          )
        ),
      ],
    );
  }
}

class _CategoryEditorCategoryList extends StatelessWidget {
  final DayBloc bloc;
  final List<Category> allCategories;

  _CategoryEditorCategoryList({
    @required this.bloc,
    @required this.allCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 138,
        child: ListView.builder(
          itemCount: allCategories.length,
          itemBuilder: (context, index) {
            final category = allCategories[index];
            return _CategoryListItem(
              bloc: bloc,
              category: category,
              isFirst: index == 0,
              isLast: index == allCategories.length - 1,
            );
          },
        ),
      ),
    );
  }
}

class _CategoryListItem extends StatelessWidget {
  final DayBloc bloc;
  final Category category;
  final bool isFirst;
  final bool isLast;

  _CategoryListItem({
    @required this.bloc,
    @required this.category,
    @required this.isFirst,
    @required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        isFirst ? SizedBox(height: 4,) : Container(),
        InkWell(
          onTap: () => bloc.onCategoryEditorCategoryClicked(category),
          onLongPress: () => bloc.onCategoryEditorCategoryLongClicked(context, category),
          child: Row(
            children: <Widget>[
              SizedBox(width: 18,),
              Padding(
                padding: const EdgeInsets.all(6),
                child: _CategoryThumbnail(
                  category: category,
                  width: 24,
                  height: 24,
                  fontSize: 14),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text(
                    category.name.isEmpty ? AppLocalizations.of(context).categoryNone : category.name,
                    style: TextStyle(
                      color: AppColors.TEXT_BLACK,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24,),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            width: double.infinity,
            height: 1,
            color: AppColors.DIVIDER,
          ),
        ),
        isLast ? SizedBox(height: 4,) : const SizedBox.shrink(),
      ],
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  static const _focusNodeKey = 'categoryEditor';

  final DayBloc bloc;
  final Category category;
  final FocusNode _focusNode;

  _CategoryEditor({
    @required this.bloc,
    @required this.category,
    @required FocusNode Function(String key) focusNodeProvider,
  }): _focusNode = focusNodeProvider(_focusNodeKey);

  @override
  StatelessElement createElement() {
    SchedulerBinding.instance.addPostFrameCallback((duration) {
      _focusNode.requestFocus();
    });
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    final addButtonEnabled = category.name.length > 0;
    final modifyButtonEnabled = category.id != Category.ID_DEFAULT && category.name.length > 0;
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 10,),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: <Widget>[
            _CategoryThumbnail(
              category: category,
              width: 24,
              height: 24,
              fontSize: 14
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4,),
                child: AppTextField(
                  focusNode: _focusNode,
                  text: category.name,
                  textSize: 14,
                  textColor: AppColors.TEXT_BLACK,
                  hintText: AppLocalizations.of(context).category,
                  hintTextSize: 14,
                  hintColor: AppColors.TEXT_BLACK_LIGHT,
                  onChanged: (s) => bloc.onEditingCategoryTextChanged(s),
                ),
              ),
            ),
            InkWell(
              onTap: addButtonEnabled ? bloc.onCreateNewCategoryClicked : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 9,),
                child: Text(
                  AppLocalizations.of(context).create,
                  style: TextStyle(
                    fontSize: 14,
                    color: addButtonEnabled ? AppColors.PRIMARY : AppColors.TEXT_BLACK_LIGHT,
                  ),
                  strutStyle: StrutStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: modifyButtonEnabled ? bloc.onModifyCategoryClicked : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 9,),
                child: Text(
                  AppLocalizations.of(context).modify,
                  style: TextStyle(
                    fontSize: 14,
                    color: modifyButtonEnabled ? AppColors.SECONDARY : AppColors.TEXT_BLACK_LIGHT,
                  ),
                  strutStyle: StrutStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(width: 15,),
          ],
        ),
      ),
    );
  }
}

class _ChoosePhotoButton extends StatelessWidget {
  final DayBloc bloc;

  _ChoosePhotoButton({
    @required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10,),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => bloc.onChoosePhotoClicked(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            color: AppColors.PRIMARY,
          ),
          child: Text(
            AppLocalizations.of(context).choosePhoto,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.TEXT_WHITE,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerItem extends StatelessWidget {
  final DayBloc bloc;
  final CategoryPicker item;
  final bool isSelected;

  _CategoryPickerItem({
    @required this.bloc,
    @required this.item,
    @required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final checkAssetName = item.isFillType ? 'assets/ic_check_white.png' : 'assets/ic_check_black.png';
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => bloc.onCategoryPickerSelected(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Container(
          width: 24,
          height: 24,
          decoration: item.isFillType ? BoxDecoration(
            shape: BoxShape.circle,
            color: item.color,
          ) : BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: item.color,
              width: 2,
            ),
          ),
          child: isSelected ? Image.asset(checkAssetName) : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _HeaderShadow extends StatefulWidget {
  final ScrollController scrollController;

  _HeaderShadow({
    Key key,
    @required this.scrollController,
  }): super(key: key);

  @override
  State createState() => _HeaderShadowState();
}

class _HeaderShadowState extends State<_HeaderShadow> {
  bool _isShadowVisible = false;
  var _scrollListener;

  @override
  void initState() {
    super.initState();
    _scrollListener = () {
      try {
        updateShadowVisibility(widget.scrollController.position.pixels > 0);
      } catch (e) {
        updateShadowVisibility(false);
      }
    };
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    super.dispose();
    widget.scrollController.removeListener(_scrollListener);
  }

  void updateShadowVisibility(bool visible) {
    setState(() {
      _isShadowVisible = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _isShadowVisible ? 6 : 0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.DIVIDER, AppColors.DIVIDER.withAlpha(0)]
        )
      ),
    );
  }
}
