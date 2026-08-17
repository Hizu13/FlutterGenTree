import '../models/event_model.dart';

/// Service lớp để quản lý logic sự kiện
class EventService {
  /// Lọc sự kiện theo tháng hiện tại
  static List<EventModel> getEventsThisMonth(
    List<EventModel> events,
    DateTime referenceDate,
  ) {
    return events
        .where(
          (event) =>
              event.date.month == referenceDate.month &&
              event.date.year == referenceDate.year,
        )
        .toList();
  }

  /// Lọc sự kiện trong tương lai
  static List<EventModel> getUpcomingEvents(
    List<EventModel> events,
    DateTime referenceDate,
  ) {
    return events.where((event) => event.date.isAfter(referenceDate)).toList();
  }

  /// Lấy tất cả sự kiện
  static List<EventModel> getAllEvents(List<EventModel> events) {
    return events;
  }

  /// Lọc sự kiện theo ngày cụ thể
  static List<EventModel> getEventsByDay(List<EventModel> events, int day) {
    return events.where((event) => event.date.day == day).toList();
  }

  /// Lấy sự kiện theo tab và ngày
  static List<EventModel> getFilteredEvents(
    List<EventModel> events,
    int tabIndex,
    int? selectedDay,
  ) {
    final now = DateTime.now();

    // Lọc theo tab
    final baseEvents = switch (tabIndex) {
      0 => getEventsThisMonth(events, now), // Tháng này
      1 => getUpcomingEvents(events, now), // Sắp tới
      _ => getAllEvents(events), // Tất cả
    };

    // Lọc theo ngày nếu tab 0 hoặc 1
    if ((tabIndex == 0 || tabIndex == 1) && selectedDay != null) {
      return getEventsByDay(baseEvents, selectedDay);
    }

    return baseEvents;
  }

  /// Xóa sự kiện theo ID
  static List<EventModel> deleteEvent(List<EventModel> events, String eventId) {
    return events.where((event) => event.id != eventId).toList();
  }

  /// Cập nhật sự kiện
  static List<EventModel> updateEvent(
    List<EventModel> events,
    EventModel updatedEvent,
  ) {
    return events.map((event) {
      if (event.id == updatedEvent.id) {
        return updatedEvent;
      }
      return event;
    }).toList();
  }

  /// Thêm sự kiện mới
  static List<EventModel> addEvent(
    List<EventModel> events,
    EventModel newEvent,
  ) {
    return [...events, newEvent];
  }

  /// Sắp xếp sự kiện theo ngày (mới nhất trước)
  static List<EventModel> sortByDate(
    List<EventModel> events, {
    bool descending = true,
  }) {
    final sorted = [...events];
    sorted.sort((a, b) {
      if (descending) {
        return b.date.compareTo(a.date);
      }
      return a.date.compareTo(b.date);
    });
    return sorted;
  }

  /// Sắp xếp sự kiện theo tên
  static List<EventModel> sortByTitle(
    List<EventModel> events, {
    bool ascending = true,
  }) {
    final sorted = [...events];
    sorted.sort((a, b) {
      if (ascending) {
        return a.title.compareTo(b.title);
      }
      return b.title.compareTo(a.title);
    });
    return sorted;
  }

  /// Tìm kiếm sự kiện theo từ khóa
  static List<EventModel> searchEvents(List<EventModel> events, String query) {
    if (query.isEmpty) return events;

    final lowerQuery = query.toLowerCase();
    return events
        .where(
          (event) =>
              event.title.toLowerCase().contains(lowerQuery) ||
              event.note.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }
}
