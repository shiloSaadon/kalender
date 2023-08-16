import 'package:flutter/material.dart';

import 'package:kalender/src/constants.dart';
import 'package:kalender/src/extentions.dart';
import 'package:kalender/src/models/calendar/calendar_event.dart';
import 'package:kalender/src/models/calendar/calendar_view_state.dart';
import 'package:kalender/src/models/view_configurations/view_confiuration_export.dart';
import 'package:kalender/src/views/multi_day_view/multi_day_view.dart';
import 'package:kalender/src/views/single_day_view/single_day_view.dart';

/// The [CalendarController] is used to control a calendar view.
///
/// * Can be used to animate to a specific date or page.
/// * Can be used to jump to a specific date or page.
/// * Can be used to navigate to a specific Event.
class CalendarController<T> with ChangeNotifier {
  CalendarController({
    DateTime? initialDate,
    DateTimeRange? calendarDateTimeRange,
  })  : selectedDate = initialDate ?? DateTime.now(),
        _dateTimeRange = calendarDateTimeRange ?? defaultDateRange;

  /// The currently selected date.
  DateTime selectedDate;

  /// The dateTimeRange that the calendar can display.
  final DateTimeRange _dateTimeRange;
  DateTimeRange get dateTimeRange => _dateTimeRange;

  /// The current [_state] of the view this controller is linked to.
  ViewState? _state;
  bool get isAttached => _state != null;

  /// The height per minute of the current view.
  /// This is only available for [SingleDayView] and [MultiDayView].
  double? get heightPerMinute => _state?.heightPerMinute?.value;

  /// The value notifier visible dateTimeRange of the current view.
  ValueNotifier<DateTimeRange>? get visibleDateTimeRange =>
      _state?.visibleDateTimeRange;

  /// The adjusted dateTimeRange of the current view.
  DateTimeRange? get adjustedDateTimeRange => _state?.adjustedDateTimeRange;

  /// The number of pages the [PageView] of the current view has.
  int? get numberOfPages => _state?.numberOfPages;

  /// The visible month of the current view.
  DateTime? get visibleMonth => _state?.month;

  /// Attaches the [CalendarController] to a [CalendarView].
  void attach(ViewState viewState) {
    _state = viewState;
  }

  /// Animates to the next page.
  ///
  /// The [duration] and [curve] can be provided to customize the animation.
  void animateToNextPage({
    Duration? duration,
    Curve? curve,
  }) {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    _state?.pageController.nextPage(
      duration: duration ?? const Duration(milliseconds: 300),
      curve: curve ?? Curves.easeInOut,
    );
    notifyListeners();
  }

  /// Animates to the previous page.
  ///
  /// The [duration] and [curve] can be provided to customize the animation.
  void animateToPreviousPage({
    Duration? duration,
    Curve? curve,
  }) {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    _state?.pageController.previousPage(
      duration: duration ?? const Duration(milliseconds: 300),
      curve: curve ?? Curves.easeInOut,
    );
    notifyListeners();
  }

  /// Jumps to the [page].
  ///  The [page] must be within the [numberOfPages].
  void jumpToPage(int page) {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    _state?.pageController.jumpToPage(page);
    notifyListeners();
  }

  /// Jumps to the [date].
  void jumpToDate(DateTime date) {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    if (_state == null) return;

    assert(
      !date.isWithin(_state!.adjustedDateTimeRange),
      'The date must be within the dateTimeRange of the Calendar.',
    );
    if (!date.isWithin(_state!.adjustedDateTimeRange)) return;

    _state!.pageController.jumpToPage(
      _state!.viewConfiguration.calculateDateIndex(
        date,
        _state!.adjustedDateTimeRange.start,
      ),
    );
    notifyListeners();
  }

  /// Animates to the [DateTime] provided.
  ///
  /// The [duration] and [curve] can be provided to customize the animation.
  Future<void> animateToDate(
    DateTime date, {
    Duration? duration,
    Curve? curve,
  }) async {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    if (_state == null) return;

    assert(
      date.isWithin(_state!.adjustedDateTimeRange),
      'The date must be within the dateTimeRange of the Calendar.',
    );
    if (!date.isWithin(_state!.adjustedDateTimeRange)) return;

    await _state!.pageController.animateToPage(
      _state!.viewConfiguration.calculateDateIndex(
        date,
        _state!.adjustedDateTimeRange.start,
      ),
      duration: duration ?? const Duration(milliseconds: 300),
      curve: curve ?? Curves.easeInOut,
    );
    notifyListeners();
  }

  /// Changes the [heightPerMinute] of the view.
  /// * This is only available for [SingleDayView] and [MultiDayView].
  void adjustHeightPerMinute(double heightPerMinute) {
    assert(
      _state != null,
      'The $_state must not be null.'
      'Please attach the $CalendarController to a view.',
    );
    assert(
      _state?.heightPerMinute != null,
      'The heightPerMinute must not be null.'
      'Please attach the $CalendarController to a $SingleDayView or $MultiDayView.',
    );
    _state?.scrollPhysics = const NeverScrollableScrollPhysics();
    _state?.heightPerMinute?.value = heightPerMinute;
    notifyListeners();
    _state?.scrollPhysics = const ScrollPhysics();
    notifyListeners();
  }

  /// Animates to the [CalendarEvent].
  Future<void> animateToEvent(
    CalendarEvent<T> event, {
    Duration? duration,
    Curve? curve,
  }) async {
    // First animate to the date of the event.
    await animateToDate(
      event.dateTimeRange.start,
      duration: duration ?? const Duration(milliseconds: 300),
      curve: curve ?? Curves.ease,
    );

    if (_state?.viewConfiguration is SingleDayViewConfiguration ||
        _state?.viewConfiguration is MultiDayViewConfiguration) {
      // Then animate to the event.
      await _state?.scrollController.animateTo(
        event.start.difference(event.start.startOfDay).inMinutes *
            heightPerMinute!,
        duration: duration ?? const Duration(milliseconds: 300),
        curve: curve ?? Curves.ease,
      );
    }
    notifyListeners();
  }
}
