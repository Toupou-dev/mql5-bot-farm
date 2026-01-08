//+------------------------------------------------------------------+
//|                                       Strategy_TimeBreakout.mqh  |
//|                                      Copyright 2026, Expert MQL5 |
//| Description: Universal Time-Box Breakout (Asian, US30, etc.)     |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"

class CStrategyTimeBreakout : public CStrategyBase {
private:
   //--- Time Settings (Now with Minutes!)
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
   int      m_lastCalculationDay;
   
   //--- Indicators
   int      m_handleATR, m_handleMA;
   double   m_maBuffer[], m_atrBuffer[], m_closeBuffer[];

public:
   // Constructor accepts Minutes now
   CStrategyTimeBreakout(string symbol, int period, 
                         int startH, int startM, int endH, int endM, 
                         double offset, int trendMa, 
                         int atrPer, double atrMult, double rrRatio, int minSL)
      : CStrategyBase(symbol, period) {
      
      m_startHour = startH; m_startMin = startM;
      m_endHour   = endH;   m_endMin   = endM;
      
      m_breakoutOffset  = offset * SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_trendMaPeriod   = trendMa;
      m_atrPeriod       = atrPer;
      m_atrMultiplier   = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance   = minSL * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      m_boxHigh = 0; m_boxLow = 0;
      m_lastCalculationDay = -1;
      
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
   //| Helper: Identify High/Low of the Asian Session                   |
   //+------------------------------------------------------------------+
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