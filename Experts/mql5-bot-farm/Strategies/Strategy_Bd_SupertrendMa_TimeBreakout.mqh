//+------------------------------------------------------------------+
//|                       Strategy_Bd_SupertrendMa_TimeBreakout.mqh  |
//|                                      Copyright 2026, Expert MQL5 |
//| Description: Exact OPR Strategy - Entry on Touch (Instant)       |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"

class CStrategyTimeBreakout : public CStrategyBase {
private:
   //--- Settings
   int      m_startHour, m_startMin; // 15:30
   int      m_endHour, m_endMin;     // 15:45
   double   m_breakoutOffset;
   int      m_emaFastPeriod, m_emaSlowPeriod;
   int      m_stPeriod;
   double   m_stMultiplier;
   double   m_riskRewardRatio, m_minSLDistance;
   
   //--- State
   double   m_boxHigh, m_boxLow;
   int      m_lastCalculationDay;
   bool     m_isTradeTakenToday; // To ensure only 1 execution per day
   
   //--- Indicators
   int      m_handleEMA20_M5, m_handleEMA50_M5, m_handleST_H1;
   double   m_ema20Buffer[], m_ema50Buffer[], m_stBuffer[];

public:
   CStrategyTimeBreakout(string symbol, int period, 
                         int startH, int startM, int endH, int endM, 
                         double offset, int emaFast, int emaSlow,
                         int stPer, double stMult, double rrRatio, int minSL)
      : CStrategyBase(symbol, period) {
      
      m_startHour = startH; m_startMin = startM;
      m_endHour   = endH;   m_endMin   = endM;
      m_breakoutOffset  = offset * SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_emaFastPeriod   = emaFast; m_emaSlowPeriod = emaSlow;
      m_stPeriod = stPer; m_stMultiplier = stMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance = minSL * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      m_boxHigh = 0; m_boxLow = 0;
      m_lastCalculationDay = -1;
      m_isTradeTakenToday = false;
      
      ArraySetAsSeries(m_ema20Buffer, true);
      ArraySetAsSeries(m_ema50Buffer, true);
      ArraySetAsSeries(m_stBuffer, true);
   }

   ~CStrategyTimeBreakout() { ObjectsDeleteAll(0, "Box_"); }

   virtual bool OnInitStrategy() override {
      m_handleEMA20_M5 = iMA(m_symbol, PERIOD_M5, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMA50_M5 = iMA(m_symbol, PERIOD_M5, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      // Ensure the name matches your compiled SuperTrend file name
      m_handleST_H1    = iCustom(m_symbol, PERIOD_H1, "Examples\\supertrend", m_stPeriod, m_stMultiplier);
      
      return (m_handleEMA20_M5 != INVALID_HANDLE && m_handleEMA50_M5 != INVALID_HANDLE && m_handleST_H1 != INVALID_HANDLE);
   }
   
   virtual void OnTickStrategy() override {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Reset daily flag
      if(dt.day_of_year != m_lastCalculationDay) {
         m_isTradeTakenToday = false;
      }

      CopyBuffer(m_handleEMA20_M5, 0, 0, 1, m_ema20Buffer);
      CopyBuffer(m_handleEMA50_M5, 0, 0, 1, m_ema50Buffer);
      CopyBuffer(m_handleST_H1, 0, 0, 1, m_stBuffer);
      
      CalculateBox();
   }
   
   virtual int GetEntrySignal() override {
      // 1. Safety checks: Box must be formed and only 1 trade per day
      if(m_boxHigh <= 0 || m_isTradeTakenToday) return 0;

      // 2. Get Real-time prices (Entry on Touch)
      double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // 3. Indicator filters alignment
      bool emaBullish = m_ema20Buffer[0] > m_ema50Buffer[0];
      bool emaBearish = m_ema20Buffer[0] < m_ema50Buffer[0];
      
      // SuperTrend Filter (Buffer 0 is usually the trend line)
      bool stBullish = currentBid > m_stBuffer[0];
      bool stBearish = currentAsk < m_stBuffer[0];

      // 4. BUY LOGIC: Price touches Box High + Offset
      if(currentAsk >= (m_boxHigh + m_breakoutOffset)) {
         if(emaBullish && stBullish) {
            m_isTradeTakenToday = true; // Lock for the day
            return 1; 
         }
      }
      
      // 5. SELL LOGIC: Price touches Box Low - Offset
      if(currentBid <= (m_boxLow - m_breakoutOffset)) {
         if(emaBearish && stBearish) {
            m_isTradeTakenToday = true; // Lock for the day
            return -1;
         }
      }
      
      return 0;
   }
   
   virtual double GetStopLossDistance() override {
      // RULE: SL is at 50% of the Opening Candle (Mid-Box)
      if(m_boxHigh <= 0 || m_boxLow <= 0) return m_minSLDistance;
      
      double midBox = (m_boxHigh + m_boxLow) / 2.0;
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double dist = MathAbs(currentPrice - midBox);
      
      return (dist < m_minSLDistance) ? m_minSLDistance : dist;
   }
   
   virtual double GetTakeProfitDistance(double slDistance) override {
      return slDistance * m_riskRewardRatio;
   }

   int GetBrokerToUserOffset() {
      datetime serverTime = TimeCurrent();
      int brokerOffset = (int)(serverTime - TimeGMT());
      int userOffset   = GetUserGMTOffset(serverTime); // France
      int nyOffset     = GetNYGMTOffset(serverTime);   // New York
      
      int diffSeconds = brokerOffset - userOffset;

      // Ajustement spécial US30 (les 2-3 semaines de décalage)
      int currentGap = (userOffset - nyOffset) / 3600;
      if(currentGap != 6) {
         int adjustment = (currentGap - 6) * 3600;
         diffSeconds -= adjustment; // On synchronise le décalage
      }
      return diffSeconds;
   }

private:
   void CalculateBox() {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Convert current time and end time to minutes for comparison
      int currentMinutesOfDay = (dt.hour * 60) + dt.min;
      int endMinutesOfDay     = (m_endHour * 60) + m_endMin;
      
      // Logic: If we passed the End Time AND haven't calculated for today
      if(currentMinutesOfDay >= endMinutesOfDay && dt.day_of_year != m_lastCalculationDay) {
         
         datetime timeCurrent = TimeCurrent();
         datetime timeStartDay = timeCurrent - (timeCurrent % 86400); 
         
         datetime t1 = timeStartDay + (m_startHour * 3600) + (m_startMin * 60);
         datetime t2 = timeStartDay + (m_endHour * 3600) + (m_endMin * 60);
         
         // Special case: If Start > End (Overnight session like 22:00 to 08:00)
         if(t1 > t2) t1 -= 86400; // Go back 1 day for start time
         
         // Use M1 data for precision (crucial for US30 15min range)
         double highs[], lows[];
         if(CopyHigh(m_symbol, PERIOD_M1, t1, t2, highs) > 0 &&
            CopyLow(m_symbol, PERIOD_M1, t1, t2, lows) > 0) 
         {
            m_boxHigh = highs[ArrayMaximum(highs)];
            m_boxLow  = lows[ArrayMinimum(lows)];
            m_lastCalculationDay = dt.day_of_year;
            
            DrawBox(t1, t2, m_boxHigh, m_boxLow);
            CLogger::Debug(StringFormat("Box Locked: %.2f - %.2f", m_boxHigh, m_boxLow));
         }
      }
   }

   int GetUserGMTOffset(datetime t) {
      MqlDateTime dt; TimeToStruct(t, dt);
      datetime march31 = StringToTime(IntegerToString(dt.year)+".03.31");
      datetime dstStart = march31 - (((dt.day_of_week == 0 ? 7 : dt.day_of_week) % 7) * 86400);
      datetime oct31 = StringToTime(IntegerToString(dt.year)+".10.31");
      datetime dstEnd = oct31 - (((dt.day_of_week == 0 ? 7 : dt.day_of_week) % 7) * 86400);
      return (t >= dstStart && t < dstEnd) ? 7200 : 3600;
   }

   int GetNYGMTOffset(datetime t) {
      MqlDateTime dt; TimeToStruct(t, dt);
      datetime march1 = StringToTime(IntegerToString(dt.year)+".03.01");
      MqlDateTime m1; TimeToStruct(march1, m1);
      int secondSunMarch = (m1.day_of_week == 0) ? 8 : (7 - m1.day_of_week + 8);
      datetime dstStart = march1 + (secondSunMarch * 86400);
      datetime nov1 = StringToTime(IntegerToString(dt.year)+".11.01");
      MqlDateTime n1; TimeToStruct(nov1, n1);
      int firstSunNov = (n1.day_of_week == 0) ? 1 : (7 - n1.day_of_week + 1);
      datetime dstEnd = nov1 + (firstSunNov * 86400);
      return (t >= dstStart && t < dstEnd) ? -14400 : -18000;
   }

   void DrawBox(datetime t1, datetime t2, double h, double l) {
      string n = "Box_" + TimeToString(t1);
      ObjectDelete(0, n);
      if(ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, h, t2, l)) {
         ObjectSetInteger(0, n, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, n, OBJPROP_BACK, true);
         ChartRedraw(0);
      }
   }
};