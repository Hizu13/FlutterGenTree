import 'dart:math' as math;

/// Lớp kết quả chuyển đổi Ngày Âm Lịch
class LunarDateResult {
  final int day;
  final int month;
  final int year;
  final bool isLeap;

  const LunarDateResult({
    required this.day,
    required this.month,
    required this.year,
    this.isLeap = false,
  });

  @override
  String toString() => '$day/$month/$year ${isLeap ? "(Nhuận)" : ""} Âm lịch';
}

/// Tiện ích chuyển đổi 2 chiều Âm lịch <-> Dương lịch Việt Nam
/// Thuật toán thiên văn chuẩn múi giờ Việt Nam (UTC+7) của GS. Hồ Ngọc Đức
class LunarSolarConverter {
  static const double timeZone = 7.0;

  static int _int(num d) => d.floor();

  /// Chuyển đổi Ngày Dương lịch (DateTime) -> Ngày Âm lịch (LunarDateResult)
  static LunarDateResult solarToLunar(DateTime solarDate) {
    final dd = solarDate.day;
    final mm = solarDate.month;
    final yy = solarDate.year;

    final int dayNumber = _jdFromDate(dd, mm, yy);
    final int k = _int((dayNumber - 2415021.0769986) / 29.530588853);
    int monthStart = _getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, timeZone);
    }
    int a11 = _getLunarMonth11(yy, timeZone);
    int b11 = a11;
    int lunarYear = yy;
    if (a11 >= monthStart) {
      lunarYear = yy - 1;
      a11 = _getLunarMonth11(yy - 1, timeZone);
    } else {
      b11 = _getLunarMonth11(yy + 1, timeZone);
    }
    final int lunarDay = dayNumber - monthStart + 1;
    final int diff = _int((monthStart - a11) / 29);
    bool isLeap = false;
    int lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final int leapMonthDiff = _getLeapMonthOffset(a11, timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          isLeap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }

    return LunarDateResult(
      day: lunarDay.clamp(1, 30),
      month: lunarMonth.clamp(1, 12),
      year: lunarYear,
      isLeap: isLeap,
    );
  }

  /// Chuyển đổi Ngày Âm lịch (day, month, year) -> Ngày Dương lịch (DateTime)
  static DateTime lunarToSolar(int lunarDay, int lunarMonth, int lunarYear, {bool isLeap = false}) {
    final a11 = _getLunarMonth11(lunarYear, timeZone);
    final b11 = _getLunarMonth11(lunarYear + 1, timeZone);
    int off = lunarMonth - 11;
    if (off < 0) {
      off += 12;
    }
    if (b11 - a11 > 365) {
      final int leapOff = _getLeapMonthOffset(a11, timeZone);
      final int leapMonth = (leapOff - 2 < 0) ? leapOff + 10 : leapOff - 2;
      if (isLeap && (lunarMonth != leapMonth)) {
        // not leap
      } else if (isLeap || (off >= leapOff)) {
        off += 1;
      }
    }
    final int k = _int((a11 - 2415021.0769986) / 29.530588853 + 0.5);
    final int monthStart = _getNewMoonDay(k + off, timeZone);
    final List<int> solar = _jdToDate(monthStart + lunarDay - 1);

    return DateTime(solar[2], solar[1], solar[0]);
  }

  // ==================== CÁC HÀM THIÊN VĂN TÍNH TOÁN ====================

  static int _jdFromDate(int dd, int mm, int yy) {
    int a = _int((14 - mm) / 12);
    int y = yy + 4800 - a;
    int m = mm + 12 * a - 3;
    int jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - _int(y / 100) + _int(y / 400) - 32045;
    if (jd < 2299161) {
      jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - 32083;
    }
    return jd;
  }

  static List<int> _jdToDate(int jd) {
    int a, b, c, d, e, day, month, year;
    if (jd > 2299160) {
      int z = jd + 1;
      int alpha = _int((z - 1867216.25) / 36524.25);
      a = z + 1 + alpha - _int(alpha / 4);
    } else {
      a = jd;
    }
    b = a + 1524;
    c = _int((b - 122.1) / 365.25);
    d = _int(365.25 * c);
    e = _int((b - d) / 30.6001);
    day = b - d - _int(30.6001 * e);
    month = e < 14 ? e - 1 : e - 13;
    year = month > 2 ? c - 4716 : c - 4715;
    return [day, month, year];
  }

  static int _getNewMoonDay(int k, double timeZone) {
    double t = k / 1236.85;
    double t2 = t * t;
    double t3 = t2 * t;
    double dr = math.pi / 180;
    double jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    double m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    double mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    double f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    double c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * m * dr);
    c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(2 * mpr * dr);
    c1 = c1 - 0.0004 * math.sin(3 * mpr * dr);
    c1 = c1 + 0.0104 * math.sin(2 * f * dr) - 0.0051 * math.sin((m + mpr) * dr);
    c1 = c1 - 0.0074 * math.sin((m - mpr) * dr) + 0.0004 * math.sin((2 * f + m) * dr);
    c1 = c1 - 0.0004 * math.sin((2 * f - m) * dr) - 0.0006 * math.sin((2 * f + mpr) * dr);
    c1 = c1 + 0.0010 * math.sin((2 * f - mpr) * dr) + 0.0005 * math.sin((m + 2 * mpr) * dr);
    double deltat;
    if (t < -11) {
      deltat = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3;
    } else {
      deltat = -0.000078 + 0.000265 * t + 0.000262 * t2;
    }
    double jdNew = jd1 + c1 - deltat;
    return _int(jdNew + 0.5 + timeZone / 24);
  }

  static int _getSunLongitude(int dayNumber, double timeZone) {
    double t = (dayNumber - 2451545.0 + 0.5 - timeZone / 24) / 36525;
    double t2 = t * t;
    double dr = math.pi / 180;
    double l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    double m = 357.52910 + 35999.05029 * t - 0.0001537 * t2;
    double c = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(m * dr);
    c = c + (0.019993 - 0.000101 * t) * math.sin(2 * m * dr) + 0.000289 * math.sin(3 * m * dr);
    double theta = l0 + c;
    double lambda = theta - 360 * _int(theta / 360);
    return _int(lambda / 30);
  }

  static int _getLunarMonth11(int yy, double timeZone) {
    final int off = _jdFromDate(31, 12, yy - 1) - 2415021;
    final int k = _int(off / 29.530588853);
    int nm = _getNewMoonDay(k, timeZone);
    final int sunLong = _getSunLongitude(nm, timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11, double timeZone) {
    final int k = _int((a11 - 2415021.0769986) / 29.530588853 + 0.5);
    int last = 0;
    int i = 1;
    int arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc != last && i < 14);
    return i - 1;
  }
}
