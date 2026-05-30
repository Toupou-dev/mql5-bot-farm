//+------------------------------------------------------------------+
//|                                                  TimeZone.mqh    |
//|                                      Copyright 2026, Expert MQL5 |
//| description: Time zone conversion with DST support               |
//+------------------------------------------------------------------+
#property strict

class CTimeZone {
public:
   static string Normalize(string tz) {
      string res = TrimString(tz);
      StringToUpper(res);
      StringReplace(res, " ", "_");
      StringReplace(res, "-", "_");
      return res;
   }

   static bool IsValid(const string tz) {
      string zone = Normalize(tz);
      if (ParseFixedOffset(zone) != INT_MAX) return true;
      if (zone == "HK" || zone == "HKT" || zone == "ASIA_HONG_KONG" || zone == "HONG_KONG") return true;
      if (zone == "SG" || zone == "SGT" || zone == "ASIA_SINGAPORE" || zone == "SINGAPORE") return true;
      if (zone == "JP" || zone == "JST" || zone == "ASIA_TOKYO" || zone == "TOKYO") return true;
      if (zone == "UTC" || zone == "GMT" || zone == "GMT0") return true;
      if (zone == "NY" || zone == "NYC" || zone == "US" || zone == "EST" || zone == "EDT" || zone == "AMERICA_NEW_YORK") return true;
      if (zone == "LDN" || zone == "LON" || zone == "UK" || zone == "BST" || zone == "EUROPE_LONDON") return true;
      if (zone == "SYD" || zone == "AUS" || zone == "AEST" || zone == "AEDT" || zone == "AUSTRALIA_SYDNEY") return true;
      return false;
   }

   static int GetOffsetMinutes(const string tz, const MqlDateTime &localDateTime) {
      string zone = Normalize(tz);
      int fixedOffset = ParseFixedOffset(zone);
      if (fixedOffset != INT_MAX)
         return fixedOffset;

      if (zone == "HK" || zone == "HKT" || zone == "ASIA_HONG_KONG" || zone == "HONG_KONG")
         return 8 * 60;
      if (zone == "SG" || zone == "SGT" || zone == "ASIA_SINGAPORE" || zone == "SINGAPORE")
         return 8 * 60;
      if (zone == "JP" || zone == "JST" || zone == "ASIA_TOKYO" || zone == "TOKYO")
         return 9 * 60;
      if (zone == "UTC" || zone == "GMT" || zone == "GMT0")
         return 0;
      if (zone == "NY" || zone == "NYC" || zone == "US" || zone == "EST" || zone == "EDT" || zone == "AMERICA_NEW_YORK")
         return IsDstNewYork(localDateTime) ? -4 * 60 : -5 * 60;
      if (zone == "LDN" || zone == "LON" || zone == "UK" || zone == "BST" || zone == "EUROPE_LONDON")
         return IsDstLondon(localDateTime) ? 1 * 60 : 0;
      if (zone == "SYD" || zone == "AUS" || zone == "AEST" || zone == "AEDT" || zone == "AUSTRALIA_SYDNEY")
         return IsDstSydney(localDateTime) ? 11 * 60 : 10 * 60;

      return INT_MAX;
   }

   static int GetOffsetMinutesFromUtc(const string tz, datetime utcTime) {
      string zone = Normalize(tz);
      int fixedOffset = ParseFixedOffset(zone);
      if (fixedOffset != INT_MAX)
         return fixedOffset;

      int baseOffset = GetStandardOffset(zone);
      if (baseOffset == INT_MAX)
         return INT_MAX;

      MqlDateTime candidate;
      UnixToDateTime(utcTime + baseOffset * 60, candidate);
      return GetOffsetMinutes(zone, candidate);
   }

   static datetime DateTimeToUnix(int year, int month, int day, int hour, int min, int sec) {
      if (month <= 2) {
         year -= 1;
         month += 12;
      }
      int era = year / 400;
      int yoe = year - era * 400;
      int doy = (153 * (month - 3) + 2) / 5 + day - 1;
      int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
      long days = era * 146097 + doe - 719468;
      return (datetime)(days * 86400 + hour * 3600 + min * 60 + sec);
   }

   static void UnixToDateTime(datetime timestamp, MqlDateTime &dt) {
      long t = (long)timestamp;
      if (t < 0) t = 0;
      dt.sec = (int)(t % 60);
      t /= 60;
      dt.min = (int)(t % 60);
      t /= 60;
      dt.hour = (int)(t % 24);
      long days = t / 24;
      dt.day_of_week = (int)((days + 4) % 7);
      if (dt.day_of_week < 0) dt.day_of_week += 7;

      long z = days + 719468;
      long era = (z >= 0 ? z : z - 146096) / 146097;
      long doe = z - era * 146097;
      long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
      long y = yoe + era * 400;
      long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
      long mp = (5 * doy + 2) / 153;
      dt.day = (int)(doy - (153 * mp + 2) / 5 + 1);
      dt.mon = (int)(mp + (mp < 10 ? 3 : -9));
      dt.year = (int)(y + (dt.mon <= 2));
      dt.day_of_year = DayOfYear(dt.year, dt.mon, dt.day);
   }

private:
   static string TrimString(string s) {
      while (StringLen(s) > 0 && StringGetCharacter(s, 0) == ' ')
         s = StringSubstr(s, 1);
      while (StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == ' ')
         s = StringSubstr(s, 0, StringLen(s) - 1);
      return s;
   }

   static int ParseFixedOffset(const string zone) {
      string z = zone;
      if (StringFind(z, "UTC") == 0)
         z = StringSubstr(z, 3);
      if (StringLen(z) == 0)
         return INT_MAX;

      bool negative = false;
      if (StringGetCharacter(z, 0) == '+')
         z = StringSubstr(z, 1);
      else if (StringGetCharacter(z, 0) == '-') {
         negative = true;
         z = StringSubstr(z, 1);
      }

      string parts[2];
      int count = StringSplit(z, ':', parts);
      if (count < 1)
         return INT_MAX;

      int hours = (int)StringToInteger(parts[0]);
      int minutes = 0;
      if (count > 1)
         minutes = (int)StringToInteger(parts[1]);

      if (hours < 0 || hours > 14 || minutes < 0 || minutes >= 60)
         return INT_MAX;

      int offset = hours * 60 + minutes;
      return negative ? -offset : offset;
   }

   static int GetStandardOffset(const string zone) {
      if (zone == "HK" || zone == "HKT" || zone == "ASIA_HONG_KONG" || zone == "HONG_KONG") return 8 * 60;
      if (zone == "SG" || zone == "SGT" || zone == "ASIA_SINGAPORE" || zone == "SINGAPORE") return 8 * 60;
      if (zone == "JP" || zone == "JST" || zone == "ASIA_TOKYO" || zone == "TOKYO") return 9 * 60;
      if (zone == "UTC" || zone == "GMT" || zone == "GMT0") return 0;
      if (zone == "NY" || zone == "NYC" || zone == "US" || zone == "EST" || zone == "EDT" || zone == "AMERICA_NEW_YORK") return -5 * 60;
      if (zone == "LDN" || zone == "LON" || zone == "UK" || zone == "BST" || zone == "EUROPE_LONDON") return 0;
      if (zone == "SYD" || zone == "AUS" || zone == "AEST" || zone == "AEDT" || zone == "AUSTRALIA_SYDNEY") return 10 * 60;
      return INT_MAX;
   }

   static bool IsDstNewYork(const MqlDateTime &dt) {
      int y = dt.year;
      int secondSundayMarch = GetNthWeekdayOfMonth(y, 3, 0, 2);
      int firstSundayNovember = GetNthWeekdayOfMonth(y, 11, 0, 1);
      if (dt.mon < 3 || dt.mon > 11) return false;
      if (dt.mon > 3 && dt.mon < 11) return true;
      if (dt.mon == 3)
         return (dt.day > secondSundayMarch) || (dt.day == secondSundayMarch && dt.hour >= 2);
      return (dt.day < firstSundayNovember) || (dt.day == firstSundayNovember && dt.hour < 2);
   }

   static bool IsDstLondon(const MqlDateTime &dt) {
      int y = dt.year;
      int lastSundayMarch = GetLastWeekdayOfMonth(y, 3, 0);
      int lastSundayOctober = GetLastWeekdayOfMonth(y, 10, 0);
      if (dt.mon < 3 || dt.mon > 10) return false;
      if (dt.mon > 3 && dt.mon < 10) return true;
      if (dt.mon == 3)
         return (dt.day > lastSundayMarch) || (dt.day == lastSundayMarch && dt.hour >= 1);
      return (dt.day < lastSundayOctober) || (dt.day == lastSundayOctober && dt.hour < 1);
   }

   static bool IsDstSydney(const MqlDateTime &dt) {
      int y = dt.year;
      int firstSundayOctober = GetNthWeekdayOfMonth(y, 10, 0, 1);
      int firstSundayApril = GetNthWeekdayOfMonth(y, 4, 0, 1);
      if (dt.mon > 4 && dt.mon < 10) return false;
      if (dt.mon < 4 || dt.mon > 10) return true;
      if (dt.mon == 10)
         return (dt.day > firstSundayOctober) || (dt.day == firstSundayOctober && dt.hour >= 2);
      return (dt.day < firstSundayApril) || (dt.day == firstSundayApril && dt.hour < 3);
   }

   static int GetNthWeekdayOfMonth(int year, int month, int weekday, int n) {
      int firstDow = DayOfWeek(year, month, 1);
      int day = 1 + ((7 + weekday - firstDow) % 7);
      return day + 7 * (n - 1);
   }

   static int GetLastWeekdayOfMonth(int year, int month, int weekday) {
      int days = DaysInMonth(year, month);
      int lastDow = DayOfWeek(year, month, days);
      int delta = (7 + lastDow - weekday) % 7;
      return days - delta;
   }

   static int DaysInMonth(int year, int month) {
      static const int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
      int result = days[month - 1];
      if (month == 2 && IsLeapYear(year)) result = 29;
      return result;
   }

   static bool IsLeapYear(int year) {
      return ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
   }

   static int DayOfWeek(int year, int month, int day) {
      if (month < 3) {
         month += 12;
         year -= 1;
      }
      int K = year % 100;
      int J = year / 100;
      int h = (day + (13 * (month + 1)) / 5 + K + K / 4 + J / 4 + 5 * J) % 7;
      return ((h + 6) % 7);
   }

   static int DayOfYear(int year, int month, int day) {
      static const int monthDays[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};
      int doy = monthDays[month - 1] + day;
      if (month > 2 && IsLeapYear(year))
         doy++;
      return doy;
   }
};
