import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:kalender/src/models/calendar_events/draggable_event.dart';

/// This widget generates draggable widgets for each visible day.
/// - These draggable widgets are used to create new events.
///
/// Uses StatefulWidget to persist [_localPosition] across rebuilds.
/// This prevents a race condition where rapid event creation causes
/// the second event to start at 00:00 due to localPosition being reset
/// to Offset.zero on widget rebuild.
class DayEventDraggableWidgets<T extends Object?> extends StatefulWidget {
  final CalendarController<T> controller;
  final CalendarCallbacks<T>? callbacks;
  final MultiDayBodyConfiguration bodyConfiguration;
  final DateTimeRange visibleDateTimeRange;
  final TimeOfDayRange timeOfDayRange;
  final double dayWidth;
  final double pageHeight;
  final double heightPerMinute;

  const DayEventDraggableWidgets({
    super.key,
    required this.controller,
    required this.bodyConfiguration,
    required this.visibleDateTimeRange,
    required this.timeOfDayRange,
    required this.pageHeight,
    required this.dayWidth,
    required this.heightPerMinute,
    required this.callbacks,
  });

  @override
  State<DayEventDraggableWidgets<T>> createState() =>
      _DayEventDraggableWidgetsState<T>();
}

class _DayEventDraggableWidgetsState<T extends Object?>
    extends State<DayEventDraggableWidgets<T>> {
  /// Persisted across rebuilds to prevent race condition when creating events quickly.
  /// Without this, rebuilds reset localPosition to Offset.zero causing events to start at 00:00.
  Offset _localPosition = Offset.zero;

  CalendarController<T> get controller => widget.controller;
  CalendarCallbacks<T>? get callbacks => widget.callbacks;
  MultiDayBodyConfiguration get bodyConfiguration => widget.bodyConfiguration;
  DateTimeRange get visibleDateTimeRange => widget.visibleDateTimeRange;
  TimeOfDayRange get timeOfDayRange => widget.timeOfDayRange;
  double get dayWidth => widget.dayWidth;
  double get pageHeight => widget.pageHeight;
  double get heightPerMinute => widget.heightPerMinute;

  @override
  Widget build(BuildContext context) {
    final allowCreation = bodyConfiguration.allowEventCreation;
    final createEventTrigger = bodyConfiguration.createEventGesture;
    return Listener(
      onPointerDown: (event) => _localPosition = event.localPosition,
      onPointerSignal: (event) => _localPosition = event.localPosition,
      onPointerMove: (event) => _localPosition = event.localPosition,
      child: Row(
        children: [
          if (allowCreation)
            for (final date in visibleDateTimeRange.days)
              switch (createEventTrigger) {
                CreateEventGesture.tap => Draggable(
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: () => _createNewEvent(date, _localPosition),
                    onDraggableCanceled: _onDragFinished,
                    onDragEnd: _onDragFinished,
                    data: Create(controllerId: controller.id),
                    feedback: Container(
                      color: Colors.transparent,
                      width: 1,
                      height: 1,
                    ),
                    child: Container(
                      color: Colors.transparent,
                      width: dayWidth,
                      height: pageHeight,
                    ),
                  ),
                CreateEventGesture.longPress => LongPressDraggable(
                    delay: const Duration(milliseconds: 200),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: () => _createNewEvent(date, _localPosition),
                    onDraggableCanceled: _onDragFinished,
                    onDragEnd: _onDragFinished,
                    data: Create(controllerId: controller.id),
                    feedback: Container(
                      color: Colors.transparent,
                      width: 1,
                      height: 1,
                    ),

                    /// The child is wrapped with a [GestureDetector] to handle single taps
                    /// for event creation. This works in conjunction with [LongPressDraggable]
                    /// The GestureDetector is added to Flutter's gesture arena, which disambiguates between a tap and a long press.
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,

                      /// This callback is triggered when a user lifts their finger after a brief tap.
                      /// It creates a new event at the tapped location.
                      onTapUp: (_) {
                        final newDateTimeRange =
                            _calculateDateTimeRange(date, _localPosition);

                        final newEvent = CalendarEvent<T>(
                          dateTimeRange: newDateTimeRange,
                        );

                        final finalEvent =
                            callbacks?.onEventCreate?.call(newEvent) ??
                                newEvent;

                        callbacks?.onEventCreated?.call(finalEvent);
                      },
                      child: Container(
                        color: Colors.transparent,
                        width: dayWidth,
                        height: pageHeight,
                      ),
                    ),
                  ),
              },
        ],
      ),
    );
  }

  /// Create the new event and select it where needed.
  void _createNewEvent(DateTime date, Offset localPosition) {
    final dateTimeRange = _calculateDateTimeRange(date, localPosition);
    final newEvent = CalendarEvent<T>(dateTimeRange: dateTimeRange);
    final event = callbacks?.onEventCreate?.call(newEvent) ?? newEvent;
    controller.setNewEvent(event);
    controller.selectEvent(event);
  }

  /// Deselect the new event.
  void _onDragFinished([_, __]) => controller.clearNewEvent();

  /// Calculate the initial dateTimeRange of a new event.
  ///
  /// [date] is the date the draggable is located at.
  /// [localPosition] is the last known position of the cursor.
  DateTimeRange _calculateDateTimeRange(DateTime date, Offset localPosition) {
    final start = _calculateTimeAndDate(date, localPosition);
    final end = start.add(bodyConfiguration.newEventDuration);
    return DateTimeRange(start: start, end: end);
  }

  /// Calculate a DateTime from the [date] of the draggable and the [localPosition] of the cursor.
  DateTime _calculateTimeAndDate(DateTime date, Offset localPosition) {
    // Calculate the duration from the top of the page to the localPosition.
    final durationFromStart = localPosition.dy ~/ heightPerMinute;
    final snapIntervalMinutes = bodyConfiguration.snapIntervalMinutes;
    final numberOfIntervals = (durationFromStart / snapIntervalMinutes).round();
    final durationFromTop =
        Duration(minutes: snapIntervalMinutes * numberOfIntervals);

    // Calculate the start of the day.
    final startOfDay = timeOfDayRange.start.toDateTime(date);

    // Add the calculated duration to the startOfDay and convert to local.
    return startOfDay.add(durationFromTop).asLocal;
  }
}
