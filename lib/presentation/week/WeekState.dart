
import 'package:todo_app/domain/entity/CheckPoint.dart';
import 'package:todo_app/domain/entity/Pet.dart';
import 'package:todo_app/domain/entity/WeekRecord.dart';
import 'package:todo_app/presentation/week/WeekScreen.dart';

enum WeekViewState {
  WHOLE_LOADING,
  NORMAL,
  NETWORK_ERROR,
}

class WeekState {
  final WeekViewState viewState;
  final int year;
  final int month;
  final int nthWeek;
  final Map<int, WeekRecord> pageIndexWeekRecordMap;
  final DateTime initialDate;
  final int initialWeekRecordPageIndex;
  final DateTime currentDate;
  final int currentWeekRecordPageIndex;
  final bool pageViewScrollEnabled;
  final Pet pet;

  // todo: Looks like one-time events shouldn't be handled this way. Maybe they should just be handled in View level, without going through Blocs.
  final bool moveToTodayEvent;
  final int animateToPageEvent;
  final bool startTutorialEvent;
  final bool scrollToTodayPreviewEvent;
  final bool showFirstCompletableDayTutorialEvent;

  WeekRecord get currentWeekRecord => pageIndexWeekRecordMap[currentWeekRecordPageIndex];

  const WeekState({
    this.viewState = WeekViewState.WHOLE_LOADING,
    this.year = 0,
    this.month = 0,
    this.nthWeek = 0,
    this.pageIndexWeekRecordMap = const {},
    this.initialDate,
    this.initialWeekRecordPageIndex = WeekScreen.INITIAL_WEEK_PAGE,
    this.currentDate,
    this.currentWeekRecordPageIndex = WeekScreen.INITIAL_WEEK_PAGE,
    this.pageViewScrollEnabled = false,
    this.pet = Pet.INVALID,

    this.moveToTodayEvent = false,
    this.animateToPageEvent = -1,
    this.startTutorialEvent = false,
    this.scrollToTodayPreviewEvent = false,
    this.showFirstCompletableDayTutorialEvent = false,
  });

  WeekRecord getWeekRecordForPageIndex(int index) {
    return pageIndexWeekRecordMap[index];
  }

  WeekState buildNew({
    WeekViewState viewState,
    int year,
    int month,
    int nthWeek,
    WeekRecord currentWeekRecord,
    WeekRecord prevWeekRecord,
    WeekRecord nextWeekRecord,
    DateTime initialDate,
    int currentWeekRecordPageIndex,
    DateTime currentDate,
    bool pageViewScrollEnabled,
    Pet pet,

    bool moveToTodayEvent,
    int animateToPageEvent,
    bool startTutorialEvent,
    bool scrollToTodayPreviewEvent,
    bool showFirstCompletableDayTutorialEvent,
  }) {
    final prevMap = this.pageIndexWeekRecordMap;
    final currentPageIndex = currentWeekRecordPageIndex ?? this.currentWeekRecordPageIndex;
    final Map<int, WeekRecord> pageIndexWeekRecordMap = {
      currentPageIndex - 1: prevWeekRecord ?? prevMap[currentPageIndex - 1],
      currentPageIndex: currentWeekRecord ?? prevMap[currentPageIndex],
      currentPageIndex + 1: nextWeekRecord ?? prevMap[currentPageIndex + 1],
    };
    return WeekState(
      viewState: viewState ?? this.viewState,
      year: year ?? this.year,
      month: month ?? this.month,
      nthWeek: nthWeek ?? this.nthWeek,
      pageIndexWeekRecordMap: pageIndexWeekRecordMap,
      initialDate: initialDate ?? this.initialDate,
      currentWeekRecordPageIndex: currentWeekRecordPageIndex ?? this.currentWeekRecordPageIndex,
      currentDate: currentDate ?? this.currentDate,
      pageViewScrollEnabled: pageViewScrollEnabled ?? this.pageViewScrollEnabled,
      pet: pet ?? this.pet,

      moveToTodayEvent: moveToTodayEvent ?? false,
      animateToPageEvent: animateToPageEvent ?? -1,
      startTutorialEvent: startTutorialEvent ?? false,
      scrollToTodayPreviewEvent: scrollToTodayPreviewEvent ?? false,
      showFirstCompletableDayTutorialEvent: showFirstCompletableDayTutorialEvent ?? false,
    );
  }

  WeekState buildNewCheckPointUpdated(CheckPoint updated) {
    return buildNew(currentWeekRecord: currentWeekRecord.buildNewCheckPointUpdated(updated));
  }
}