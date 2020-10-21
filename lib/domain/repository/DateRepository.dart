
abstract class DateRepository {
  static final INVALID_DATE = DateTime(0);

  Future<DateTime> getToday();
  Future<bool> syncTodayWithServer();
}