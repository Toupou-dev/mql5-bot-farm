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
   int      m_startHour, m_startMin; // 15:30 (Server Time)
   int      m_endHour,   m_endMin;   // 15:45 (Server Time)
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

   //+------------------------------------------------------------------+
   //| Destructor: Cleans up graphical objects from the chart           |
   //+------------------------------------------------------------------+
   ~CStrategyTimeBreakout() { ObjectsDeleteAll(0, "Box_"); }
   // Remove all rectangles drawn by this strategy

   //+------------------------------------------------------------------+
   //| Initialization: Create Indicator Handles                         |
   //+------------------------------------------------------------------+
   virtual bool OnInitStrategy() override {
      // EMA Filters on M5 Timeframe
      m_handleEMA20_M5 = iMA(m_symbol, PERIOD_M5, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMA50_M5 = iMA(m_symbol, PERIOD_M5, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      // SuperTrend Filter on H1 Timeframe
      m_handleST_H1    = iCustom(m_symbol, PERIOD_H1, "Examples\\supertrend", m_stPeriod, m_stMultiplier);
      
      return (m_handleEMA20_M5 != INVALID_HANDLE && m_handleEMA50_M5 != INVALID_HANDLE && m_handleST_H1 != INVALID_HANDLE);
   }
   
   //+------------------------------------------------------------------+
   //| Main Update Loop (Called every tick)                             |
   //+------------------------------------------------------------------+
   virtual void OnTickStrategy() override {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Reset daily flag
      if(dt.day_of_year != m_lastCalculationDay) {
         m_isTradeTakenToday = false;
      }

      // Update data buffers
      CopyBuffer(m_handleEMA20_M5, 0, 0, 1, m_ema20Buffer);
      CopyBuffer(m_handleEMA50_M5, 0, 0, 1, m_ema50Buffer);
      CopyBuffer(m_handleST_H1, 0, 0, 1, m_stBuffer);
      
      CalculateBox();
   }
   
   //+------------------------------------------------------------------+
   //| Entry Logic: Check for Breakout                                  |
   //+------------------------------------------------------------------+
   virtual int GetEntrySignal() override {
      // 1. Safety checks: Box must be formed and only 1 trade per day
      if(m_boxHigh <= 0 || m_isTradeTakenToday) return 0;

      // 2. Get Real-time prices (Entry on Touch)
      double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // 3. Indicator filters alignment
      bool emaBullish = m_ema20Buffer[0] > m_ema50Buffer[0];
      bool emaBearish = m_ema20Buffer[0] < m_ema50Buffer[0];
      
      // SuperTrend Filter (Checking current price vs SuperTrend line)
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
   
   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Stop Loss Distance                    |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() override
   {
      // RULE: SL is at 50% of the Opening Candle (Mid-Box)
      if (m_boxHigh <= 0 || m_boxLow <= 0)
         return m_minSLDistance;

      double midBox = (m_boxHigh + m_boxLow) / 2.0;
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double dist = MathAbs(currentPrice - midBox);

      return (dist < m_minSLDistance) ? m_minSLDistance : dist;
   }

   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Take Profit Distance                  |
   //+------------------------------------------------------------------+
   virtual double GetTakeProfitDistance(double slDistance) override {
      return slDistance * m_riskRewardRatio;
   }

private:
   //+------------------------------------------------------------------+
   //| Helper: Identify High/Low of the Opening Session                 |
   //+------------------------------------------------------------------+
   void CalculateBox() {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Use direct Server Time for calculations (Optimization friendly)
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
            CLogger::Debug(StringFormat("US30 Box Locked: %.2f - %.2f", m_boxHigh, m_boxLow));
         }
      }
   }
   
   void DrawBox(datetime t1, datetime t2, double h, double l) {
      string n = "Box_" + TimeToString(t1);
      ObjectDelete(0, n);
      if(ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, h, t2, l)) {
         ObjectSetInteger(0, n, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, n, OBJPROP_BACK, true);
         ChartRedraw(0);
      }
   }
};