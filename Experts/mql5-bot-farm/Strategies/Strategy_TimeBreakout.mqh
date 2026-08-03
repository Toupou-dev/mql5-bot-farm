//+------------------------------------------------------------------+
//|                                       Strategy_TimeBreakout.mqh  |
//|                                      Copyright 2026, Expert MQL5 |
//| Description: Universal Time-Box Breakout (Asian, US30, etc.)     |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/TimeZone.mqh"

class CStrategyTimeBreakout : public CStrategyBase {
private:
   //--- Time Settings (Now with Minutes + Time Zone)
   string   m_timeZone;
   int      m_startHour, m_startMin;
   int      m_endHour, m_endMin;
   
   //--- Filters
   double   m_breakoutOffset;
   int      m_trendMaPeriod;
   
   //--- Risk
   int      m_atrPeriod;
   double   m_atrMultiplier;
   double   m_riskRewardRatio;
   double   m_minSLDistance;
   
   //--- State
   double   m_boxHigh, m_boxLow;
   int      m_lastCalculationLocalDay;
   
   //--- Indicators
   int      m_handleATR, m_handleMA;
   double   m_maBuffer[], m_atrBuffer[], m_closeBuffer[];

public:
   // Constructor accepts local session times in a named time zone
   CStrategyTimeBreakout(string symbol, int period,
                         string timeZone,
                         int startH, int startM, int endH, int endM,
                         double offset, int trendMa,
                         int atrPer, double atrMult, double rrRatio, int minSL)
      : CStrategyBase(symbol, period) {
      
      m_timeZone = timeZone;
      m_startHour = startH; m_startMin = startM;
      m_endHour   = endH;   m_endMin   = endM;
      
      m_breakoutOffset  = offset * SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_trendMaPeriod   = trendMa;
      m_atrPeriod       = atrPer;
      m_atrMultiplier   = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance   = minSL * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      m_boxHigh = 0; m_boxLow = 0;
      m_lastCalculationLocalDay = -1;
      
      ArraySetAsSeries(m_maBuffer, true);
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);
   }

   //+------------------------------------------------------------------+
   //| Destructor: Cleans up graphical objects from the chart           |
   //+------------------------------------------------------------------+
   ~CStrategyTimeBreakout() { ObjectsDeleteAll(0, "Box_"); }
   // Remove all rectangles drawn by this strategy
   //+------------------------------------------------------------------+
   //| Initialization: Create Indicator Handles                         |
   //+------------------------------------------------------------------+
   virtual bool OnInitStrategy() override {
      if (!CTimeZone::IsValid(m_timeZone)) {
         CLogger::Error("TimeBreakout: Invalid time zone specified: " + m_timeZone);
         return false;
      }
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, m_atrPeriod);
      m_handleMA  = iMA(m_symbol, (ENUM_TIMEFRAMES)m_period, m_trendMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleATR == INVALID_HANDLE || m_handleMA == INVALID_HANDLE) {
         CLogger::Error("TimeBreakout: Failed to initialize indicators.");
         return false;
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Main Update Loop (Called every tick)                             |
   //+------------------------------------------------------------------+
   virtual void OnTickStrategy() override {
      // Update data buffers
      CopyBuffer(m_handleATR, 0, 0, 1, m_atrBuffer);
      CopyBuffer(m_handleMA, 0, 0, 1, m_maBuffer);
      CopyClose(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, 2, m_closeBuffer);
      
      // Check if we need to calculate the Asian Box for today
      CalculateBox();
   }
   
   //+------------------------------------------------------------------+
   //| Entry Logic: Check for Breakout                                  |
   //+------------------------------------------------------------------+
   virtual int GetEntrySignal() override {
      // 1. Ensure the box is valid
      if(m_boxHigh == 0 || m_boxLow == 0) return 0;
      
      double closePrice = m_closeBuffer[1];
      double trendMA    = m_maBuffer[0];
      
      // 2. BUY SIGNAL
      // Logic: Price closes ABOVE the Asian High (+ Offset)
      // Filter: Price must be ABOVE the Trend MA
      if(closePrice > (m_boxHigh + m_breakoutOffset)) {
         if(closePrice > trendMA){
            return 1;
         }
      }
      
      // 3. SELL SIGNAL
      // Logic: Price closes BELOW the Asian Low (- Offset)
      // Filter: Price must be BELOW the Trend MA
      if(closePrice < (m_boxLow - m_breakoutOffset)) {
         if(closePrice < trendMA) return -1;
      }
      return 0;
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Stop Loss Distance                    |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() override {
      if(ArraySize(m_atrBuffer) < 1) return 0.0;
      // Dynamic SL based on Volatility
      double sl = m_atrBuffer[0] * m_atrMultiplier;

      // Enforce Minimum Safety Distance
      return (sl < m_minSLDistance) ? m_minSLDistance : sl;
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Take Profit Distance                  |
   //+------------------------------------------------------------------+
   virtual double GetTakeProfitDistance(double slDistance) override {
      return slDistance * m_riskRewardRatio;
   }

private:
   //+------------------------------------------------------------------+
   //| Helper: Identify High/Low of the Session                   |
   //+------------------------------------------------------------------+
   void CalculateBox() {
      MqlDateTime localNow;
      if (!GetCurrentLocalTime(localNow))
         return;

      int currentLocalMinutes = (localNow.hour * 60) + localNow.min;
      int localDayKey         = (localNow.year * 1000) + localNow.day_of_year;

      if (localDayKey == m_lastCalculationLocalDay)
         return;

      if (!HasLocalSessionEnded(currentLocalMinutes))
         return;

      MqlDateTime sessionStart = localNow;
      MqlDateTime sessionEnd   = localNow;
      sessionStart.hour = m_startHour;
      sessionStart.min  = m_startMin;
      sessionStart.sec  = 0;
      sessionEnd.hour   = m_endHour;
      sessionEnd.min    = m_endMin;
      sessionEnd.sec    = 0;

      int startLocalMinutes = (m_startHour * 60) + m_startMin;
      int endLocalMinutes   = (m_endHour * 60) + m_endMin;
      if (startLocalMinutes > endLocalMinutes) {
         datetime utcNow = TimeGMT();
         int localOffset = CTimeZone::GetOffsetMinutesFromUtc(m_timeZone, utcNow);
         if (localOffset == INT_MAX)
            return;

         datetime localYesterday = utcNow + localOffset * 60 - 86400;
         MqlDateTime previousDay;
         CTimeZone::UnixToDateTime(localYesterday, previousDay);
         sessionStart.year = previousDay.year;
         sessionStart.mon  = previousDay.mon;
         sessionStart.day  = previousDay.day;
      }

      datetime t1 = ConvertLocalToServer(sessionStart);
      datetime t2 = ConvertLocalToServer(sessionEnd);

      double highs[], lows[];
      if (CopyHigh(m_symbol, PERIOD_M1, t1, t2, highs) > 0 &&
          CopyLow(m_symbol, PERIOD_M1, t1, t2, lows) > 0) {
         m_boxHigh = highs[ArrayMaximum(highs)];
         m_boxLow  = lows[ArrayMinimum(lows)];
         m_lastCalculationLocalDay = localDayKey;

         DrawBox(t1, t2, m_boxHigh, m_boxLow);
         CLogger::Debug(StringFormat("Box Locked [%s]: %.2f - %.2f", m_timeZone, m_boxHigh, m_boxLow));
      }
   }

   bool GetCurrentLocalTime(MqlDateTime &localTime) {
      datetime utcNow = TimeGMT();
      int localOffset = CTimeZone::GetOffsetMinutesFromUtc(m_timeZone, utcNow);
      if (localOffset == INT_MAX)
         return false;

      datetime localStamp = utcNow + localOffset * 60;
      CTimeZone::UnixToDateTime(localStamp, localTime);
      return true;
   }

   bool HasLocalSessionEnded(int currentLocalMinutes) {
      int startLocalMinutes = (m_startHour * 60) + m_startMin;
      int endLocalMinutes   = (m_endHour * 60) + m_endMin;
      if (startLocalMinutes <= endLocalMinutes)
         return currentLocalMinutes >= endLocalMinutes;

      // Overnight session: end occurs on the next local day.
      if (currentLocalMinutes < startLocalMinutes)
         return currentLocalMinutes >= endLocalMinutes;
      return false;
   }

   datetime ConvertLocalToServer(const MqlDateTime &localDateTime)
   {
      int localOffset = CTimeZone::GetOffsetMinutes(m_timeZone, localDateTime);
      int serverOffset = (int)((TimeCurrent() - TimeGMT()) / 60);

      MqlDateTime dt = localDateTime; // copy to modify
      datetime serverStamp = StructToTime(dt);

      return serverStamp - ((localOffset - serverOffset) * 60);
   }

   void DrawBox(datetime t1, datetime t2, double h, double l) {
      string n = "Box_" + TimeToString(t1);
      if(ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, h, t2, l)) {
         ObjectSetInteger(0, n, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, n, OBJPROP_BACK, true);
         ChartRedraw(0);
      }
   }
};