//+------------------------------------------------------------------+
//|                                                  TimeFilters.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| description: Module to filter trading based on HH:MM time range  |
//+------------------------------------------------------------------+
#property strict

class CTimeFilter {
private:
   int m_startMinutes; // Total minutes since 00:00 for the start time
   int m_endMinutes;   // Total minutes since 00:00 for the end time

public:
   //--- Constructor: Receives "HH:MM" format (e.g., "09:30", "17:45")
   CTimeFilter(string startStr, string endStr) {
      m_startMinutes = TimeStringToMinutes(startStr);
      m_endMinutes   = TimeStringToMinutes(endStr);
   }
   
   //--- Main function to check if we are allowed to trade
   bool IsTradingTime() {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Convert current time to total minutes from midnight
      int currentMinutes = (dt.hour * 60) + dt.min;
      
      // Logic:
      // Case 1: Day Session (ex: 07:00 -> 19:00)
      // Start is less than End
      if(m_startMinutes < m_endMinutes) {
         if(currentMinutes >= m_startMinutes && currentMinutes < m_endMinutes) return true;
      }
      
      //Case 2: Night Session (ex: 20:00 -> 06:00)
      // Start is greater than End
      else {
         if(currentMinutes >= m_startMinutes || currentMinutes < m_endMinutes) return true;
      }
      
      return false;
   }

private:
   //--- Helper method to convert "HH:MM" string to integer minutes
   int TimeStringToMinutes(string timeStr) {
      string sep[];
      ushort u_sep = StringGetCharacter(":", 0); // Separator ':'
      
      // Split the string based on the separator
      if(StringSplit(timeStr, u_sep, sep) < 2) {
         Print("[ERROR] TimeFilter: Incorrect format (Expected HH:MM)");
         return 0;
      }
      
      int h = (int)StringToInteger(sep[0]);
      int m = (int)StringToInteger(sep[1]);
      
      // Calculate and return total minutes
      return (h * 60) + m;
   }
};