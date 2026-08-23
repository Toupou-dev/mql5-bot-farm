//+------------------------------------------------------------------+
//|                                       Strategy_TimeBreakout.mqh  |
//|                                      Copyright 2026, Expert MQL5 |
//| Description: Universal Time-Box Breakout (Asian, US30, etc.)     |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/TimeZone.mqh"

class CStrategyTimeBreakout : public CStrategyBase
{
private:
   //--- Time Settings (Now with Minutes + Time Zone)
   string m_timeZone;
   int m_startHour, m_startMin;
   int m_endHour, m_endMin;

   //--- Filters
   double m_breakoutOffset;
   int m_trendMaPeriod;

   //--- Risk
   int m_atrPeriod;
   double m_atrMultiplier;
   double m_riskRewardRatio;
   double m_minSLDistance;

   //--- State
   double m_boxHigh, m_boxLow;
   int m_lastCalculationLocalDay;

   //--- Indicators
   int m_handleATR, m_handleMA;
   double m_maBuffer[], m_atrBuffer[], m_closeBuffer[];

public:
   // Constructor accepts local session times in a named time zone
   CStrategyTimeBreakout(string symbol, int period,
                         string timeZone,
                         int startH, int startM, int endH, int endM,
                         double offset, int trendMa,
                         int atrPer, double atrMult, double rrRatio, int minSL)
       : CStrategyBase(symbol, period)
   {

      m_timeZone = timeZone;
      m_startHour = startH;
      m_startMin = startM;
      m_endHour = endH;
      m_endMin = endM;

      m_breakoutOffset = offset * SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_trendMaPeriod = trendMa;
      m_atrPeriod = atrPer;
      m_atrMultiplier = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance = minSL * SymbolInfoDouble(symbol, SYMBOL_POINT);

      m_boxHigh = 0;
      m_boxLow = 0;
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
   virtual bool OnInitStrategy() override
   {
      if (!CTimeZone::IsValid(m_timeZone))
      {
         CLogger::Error("TimeBreakout: Invalid TZ: " + m_timeZone);
         return false;
      }

      // Live synchronization test
      MqlDateTime testNow = {0};
      if (GetCurrentLocalTime(testNow))
      {
         datetime srv = TimeTradeServer();
         MqlDateTime serverTime = {0};
         TimeToStruct(srv, serverTime);
         CLogger::Log(StringFormat("SYNC CHECK: Local Time in %s is %02d:%02d | Broker Server Time is %02d:%02d",
                                    m_timeZone, testNow.hour, testNow.min,
                                    serverTime.hour, serverTime.min));
      }
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, m_atrPeriod);
      m_handleMA = iMA(m_symbol, (ENUM_TIMEFRAMES)m_period, m_trendMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if (m_handleATR == INVALID_HANDLE || m_handleMA == INVALID_HANDLE)
      {
         CLogger::Error("TimeBreakout: Failed to initialize indicators.");
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Main Update Loop (Called every tick)                             |
   //+------------------------------------------------------------------+
   virtual void OnTickStrategy() override
   {
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
   virtual int GetEntrySignal() override
   {
      // 1. Ensure the box is valid
      if (m_boxHigh == 0 || m_boxLow == 0)
         return 0;

      double closePrice = m_closeBuffer[1];
      double trendMA = m_maBuffer[0];

      // 2. BUY SIGNAL
      // Logic: Price closes ABOVE the Asian High (+ Offset)
      // Filter: Price must be ABOVE the Trend MA
      if (closePrice > (m_boxHigh + m_breakoutOffset))
      {
         if (closePrice > trendMA)
         {
            return 1;
         }
      }

      // 3. SELL SIGNAL
      // Logic: Price closes BELOW the Asian Low (- Offset)
      // Filter: Price must be BELOW the Trend MA
      if (closePrice < (m_boxLow - m_breakoutOffset))
      {
         if (closePrice < trendMA)
            return -1;
      }
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Stop Loss Distance                    |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() override
   {
      if (ArraySize(m_atrBuffer) < 1)
         return 0.0;
      // Dynamic SL based on Volatility
      double sl = m_atrBuffer[0] * m_atrMultiplier;

      // Enforce Minimum Safety Distance
      return (sl < m_minSLDistance) ? m_minSLDistance : sl;
   }

   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Take Profit Distance                  |
   //+------------------------------------------------------------------+
   virtual double GetTakeProfitDistance(double slDistance) override
   {
      return slDistance * m_riskRewardRatio;
   }

private:
   bool HasLocalSessionEnded(int currentLocalMinutes)
   {
      int startLocalMinutes = (m_startHour * 60) + m_startMin;
      int endLocalMinutes = (m_endHour * 60) + m_endMin;
      if (startLocalMinutes <= endLocalMinutes)
         return currentLocalMinutes >= endLocalMinutes;

      // Overnight session: end occurs on the next local day.
      if (currentLocalMinutes < startLocalMinutes)
         return currentLocalMinutes >= endLocalMinutes;
      return false;
   }

   //+------------------------------------------------------------------+
   //| Helper: Identify High/Low of the Session                   |
   //+------------------------------------------------------------------+
   void CalculateBox()
   {
      MqlDateTime localNow = {0};
      if (!GetCurrentLocalTime(localNow))
         return;

      int currentLocalMinutes = (localNow.hour * 60) + localNow.min;
      int localDayKey = (localNow.year * 1000) + localNow.day_of_year;

      // Return if the box was already calculated for this local day
      if (localDayKey == m_lastCalculationLocalDay)
         return;

      // Check whether the session has ended in the target time zone
      if (!HasLocalSessionEnded(currentLocalMinutes))
         return;

      MqlDateTime sessionStart = localNow;
      MqlDateTime sessionEnd = localNow;

      sessionStart.hour = m_startHour;
      sessionStart.min = m_startMin;
      sessionStart.sec = 0;

      sessionEnd.hour = m_endHour;
      sessionEnd.min = m_endMin;
      sessionEnd.sec = 0;

      // Handle sessions spanning two calendar days (e.g. Tokyo)
      int startLocalMinutes = (m_startHour * 60) + m_startMin;
      int endLocalMinutes = (m_endHour * 60) + m_endMin;

      if (startLocalMinutes > endLocalMinutes)
      {
         datetime utcNow = TimeGMT();
         int localOffset = CTimeZone::GetOffsetMinutes(m_timeZone, utcNow);

         datetime localYesterday = utcNow + localOffset * 60 - 86400;
         MqlDateTime previousDay = {0};
         TimeToStruct(localYesterday, previousDay);
         sessionStart.year = previousDay.year;
         sessionStart.mon = previousDay.mon;
         sessionStart.day = previousDay.day;
      }

      datetime t1 = ConvertLocalToServer(sessionStart);
      datetime t2 = ConvertLocalToServer(sessionEnd);

      double highs[], lows[];
      // Use PERIOD_M1 for maximum box precision
      if (CopyHigh(m_symbol, PERIOD_M1, t1, t2, highs) > 0 &&
          CopyLow(m_symbol, PERIOD_M1, t1, t2, lows) > 0)
      {
         int maxIdx = ArrayMaximum(highs);
         int minIdx = ArrayMinimum(lows);

         if (maxIdx >= 0 && minIdx >= 0)
         {
            m_boxHigh = highs[maxIdx];
            m_boxLow = lows[minIdx];
            m_lastCalculationLocalDay = localDayKey;

            DrawBox(t1, t2, m_boxHigh, m_boxLow);

            // Important feedback: display the corresponding server time
            CLogger::Log(StringFormat("Box SUCCESS: TargetZone=%s | ServerStart=%s | ServerEnd=%s",
                                      m_timeZone, TimeToString(t1), TimeToString(t2)));
         }
      }
   }

   bool GetCurrentLocalTime(MqlDateTime &localTime) {
      datetime srvNow = TimeTradeServer();
      datetime gmtNow = TimeGMT();
      
      // Calculate the broker offset from GMT (e.g. +2 or +3)
      int brokerOffsetMin = (int)((srvNow - gmtNow) / 60);
      
      // Calculate the target time zone offset (e.g. HK = +8)
      int targetOffsetMin = CTimeZone::GetOffsetMinutes(m_timeZone, srvNow);
      
      // Local time = Server time - Broker offset + Target offset
      datetime localStamp = srvNow - (brokerOffsetMin * 60) + (targetOffsetMin * 60);
      
      TimeToStruct(localStamp, localTime);
      return true;
   }

   datetime ConvertLocalToServer(const MqlDateTime &localDateTime) {
      datetime srvNow = TimeTradeServer();
      datetime gmtNow = TimeGMT();
      int brokerOffsetMin = (int)((srvNow - gmtNow) / 60);
      
      int targetOffsetMin = CTimeZone::GetOffsetMinutes(m_timeZone, srvNow);
      
      datetime localUnix = StructToTime(localDateTime);
      // Reverse conversion: Local -> GMT -> Server
      return localUnix - (targetOffsetMin * 60) + (brokerOffsetMin * 60);
   }

   void DrawBox(datetime startTime, datetime endTime, double boxHigh, double boxLow)
   {
      string objectName = StringFormat("Box_%s", TimeToString(startTime, TIME_DATE));
      ObjectDelete(0, objectName);

      if (!ObjectCreate(0, objectName, OBJ_RECTANGLE, 0,
                        startTime, boxHigh, endTime, boxLow))
         return;

      ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objectName, OBJPROP_FILL, false);
      ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
   }
};