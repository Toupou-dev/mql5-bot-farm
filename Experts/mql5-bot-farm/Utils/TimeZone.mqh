//+------------------------------------------------------------------+
//|                                                  TimeZone.mqh    |
//|                                      Copyright 2026, Expert MQL5 |
//+------------------------------------------------------------------+
#property strict

class CTimeZone {
public:
   static string Normalize(string tz) {
      StringToUpper(tz);
      return tz;
   }

   static bool IsValid(const string tz) {
      string zone = tz; StringToUpper(zone);
      return (GetStandardOffset(zone) != INT_MAX);
   }

   // Calcule le décalage réel (Standard + DST) pour une zone donnée
   static int GetOffsetMinutes(const string tz, datetime timeServer) {
      string zone = tz; StringToUpper(zone);
      int baseOffset = GetStandardOffset(zone);
      if (baseOffset == INT_MAX) return 0;

      MqlDateTime dt;
      TimeToStruct(timeServer, dt);

      if (zone == "NY" || zone == "NYC" || zone == "AMERICA_NEW_YORK")
         return IsDstNewYork(dt) ? -4 * 60 : -5 * 60;
      if (zone == "LDN" || zone == "LON" || zone == "EUROPE_LONDON")
         return IsDstLondon(dt) ? 1 * 60 : 0;
      if (zone == "SYD" || zone == "AUSTRALIA_SYDNEY")
         return IsDstSydney(dt) ? 11 * 60 : 10 * 60;

      return baseOffset;
   }

   static int GetStandardOffset(const string zone) {
      if (zone == "HK" || zone == "HKT") return 8 * 60;
      if (zone == "JP" || zone == "JST") return 9 * 60;
      if (zone == "UTC" || zone == "GMT") return 0;
      if (zone == "NY" || zone == "NYC" || zone == "AMERICA_NEW_YORK") return -5 * 60;
      if (zone == "LDN" || zone == "LON" || zone == "EUROPE_LONDON") return 0;
      if (zone == "SYD" || zone == "AUSTRALIA_SYDNEY") return 10 * 60;
      if (zone == "FR" || zone == "PARIS") return 1 * 60;
      return INT_MAX;
   }

private:
   static bool IsDstNewYork(const MqlDateTime &dt) {
      if (dt.mon < 3 || dt.mon > 11) return false;
      if (dt.mon > 3 && dt.mon < 11) return true;
      int secondSunMarch = 14 - (dt.year * 5 / 4 + 1) % 7;
      int firstSunNov = 7 - (dt.year * 5 / 4 + 1) % 7;
      if (dt.mon == 3) return dt.day >= secondSunMarch;
      return dt.day < firstSunNov;
   }

   static bool IsDstLondon(const MqlDateTime &dt) {
      if (dt.mon < 3 || dt.mon > 10) return false;
      if (dt.mon > 3 && dt.mon < 10) return true;
      int lastSunMarch = 31 - (dt.year * 5 / 4 + 4) % 7;
      int lastSunOct = 31 - (dt.year * 5 / 4 + 1) % 7;
      if (dt.mon == 3) return dt.day >= lastSunMarch;
      return dt.day < lastSunOct;
   }

   static bool IsDstSydney(const MqlDateTime &dt) {
      if (dt.mon > 4 && dt.mon < 10) return false;
      int firstSunOct = 7 - (dt.year * 5 / 4 + 1) % 7;
      int firstSunApril = 7 - (dt.year * 5 / 4 + 1) % 7;
      if (dt.mon == 10) return dt.day >= firstSunOct;
      if (dt.mon == 4) return dt.day < firstSunApril;
      return true;
   }
};