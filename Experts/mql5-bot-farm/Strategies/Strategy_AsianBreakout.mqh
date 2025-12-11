//+------------------------------------------------------------------+
//|                                      Strategy_AsianBreakout.mqh  |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Time-based structural breakout (Asia > London)      |
//|              Includes Visual Debugging (Box Drawing)             |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"

class CStrategyAsianBreakout : public CStrategyBase {
private:
   //--- Strategy Parameters
   int      m_asianStartHour;    // Start time of the range (e.g., 00:00)
   int      m_asianEndHour;      // End time of the range (e.g., 08:00)
   double   m_breakoutOffset;    // Points added to High/Low to confirm breakout
   
   //--- Trend Filter Parameters
   int      m_trendMaPeriod;     // Period for the Trend Moving Average (e.g., 200)
   
   //--- Risk Parameters
   int      m_atrPeriod;         // Period for ATR calculation (Volatility)
   double   m_atrMultiplier;     // Multiplier for Stop Loss distance
   double   m_riskRewardRatio;   // Target Reward relative to Risk
   double   m_minSLDistance;     // Minimum allowed Stop Loss in price units
   
   //--- Internal State Variables
   double   m_asianHigh;         // High price of the calculated box
   double   m_asianLow;          // Low price of the calculated box
   int      m_lastCalculationDay;// Stores the day of year to prevent recalc
   
   //--- Indicators & Buffers
   int      m_handleATR;
   int      m_handleMA;
   double   m_maBuffer[];
   double   m_atrBuffer[];
   double   m_closeBuffer[];     // Buffer to store Close prices

public:
   //+------------------------------------------------------------------+
   //| Constructor: Initialize parameters and buffers                   |
   //+------------------------------------------------------------------+
   CStrategyAsianBreakout(string symbol, int period, 
                          int asianStart, int asianEnd, double offsetPoints,
                          int trendMaPer, int atrPer, double atrMult, double rrRatio, int minSL)
      : CStrategyBase(symbol, period) {
      
      m_asianStartHour  = asianStart;
      m_asianEndHour    = asianEnd;
      m_breakoutOffset  = offsetPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      m_trendMaPeriod   = trendMaPer;
      m_atrPeriod       = atrPer;
      m_atrMultiplier   = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance   = minSL * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Initialize state
      m_asianHigh = 0;
      m_asianLow  = 0;
      m_lastCalculationDay = -1;
      
      // Set buffers as TimeSeries (Index 0 = Current Candle)
      ArraySetAsSeries(m_maBuffer, true);
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor: Cleans up graphical objects from the chart           |
   //+------------------------------------------------------------------+
   ~CStrategyAsianBreakout() {
      // Remove all rectangles drawn by this strategy
      ObjectsDeleteAll(0, "AsianBox_");
   }
   
   //+------------------------------------------------------------------+
   //| Initialization: Create Indicator Handles                         |
   //+------------------------------------------------------------------+
   virtual bool OnInitStrategy() override {
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, m_atrPeriod);
      m_handleMA  = iMA(m_symbol, (ENUM_TIMEFRAMES)m_period, m_trendMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_handleATR == INVALID_HANDLE || m_handleMA == INVALID_HANDLE) {
         CLogger::Error("AsianBreakout: Failed to initialize indicators.");
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
      CalculateAsianBox();
   }
   
   //+------------------------------------------------------------------+
   //| Entry Logic: Check for Breakout                                  |
   //+------------------------------------------------------------------+
   virtual int GetEntrySignal() override {
      // 1. Ensure the box is valid
      if(m_asianHigh == 0 || m_asianLow == 0) return 0;
      
      double closePrice = m_closeBuffer[1]; // We check the closed candle
      double trendMA    = m_maBuffer[0];
      
      // 2. BUY SIGNAL
      // Logic: Price closes ABOVE the Asian High (+ Offset)
      // Filter: Price must be ABOVE the Trend MA
      if(closePrice > (m_asianHigh + m_breakoutOffset)) {
         if(closePrice > trendMA) {
            return 1;
         }
      }
      
      // 3. SELL SIGNAL
      // Logic: Price closes BELOW the Asian Low (- Offset)
      // Filter: Price must be BELOW the Trend MA
      if(closePrice < (m_asianLow - m_breakoutOffset)) {
         if(closePrice < trendMA) {
            return -1;
         }
      }
      
      return 0; // No Signal
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management: Calculate Stop Loss Distance                    |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() override {
      if(ArraySize(m_atrBuffer) < 1) return 0.0;
      
      // Dynamic SL based on Volatility
      double sl = m_atrBuffer[0] * m_atrMultiplier;
      
      // Enforce Minimum Safety Distance
      if(sl < m_minSLDistance) sl = m_minSLDistance;
      
      return sl;
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
   void CalculateAsianBox() {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Only execute logic if we are past the End Hour AND haven't done it today
      if(dt.hour >= m_asianEndHour && dt.day_of_year != m_lastCalculationDay) {
         
         datetime timeCurrent = TimeCurrent();
         // Calculate 00:00 of the current day
         datetime timeStartOfToday = timeCurrent - (timeCurrent % 86400); 
         
         // Define Start and End timestamps for the box
         datetime timeAsianStart = timeStartOfToday + (m_asianStartHour * 3600);
         datetime timeAsianEnd   = timeStartOfToday + (m_asianEndHour * 3600);
         
         // Retrieve Highs and Lows for that period
         double highs[], lows[];
         if(CopyHigh(m_symbol, PERIOD_M15, timeAsianStart, timeAsianEnd, highs) > 0 &&
            CopyLow(m_symbol, PERIOD_M15, timeAsianStart, timeAsianEnd, lows) > 0) 
         {
            // Store the highest High and lowest Low
            m_asianHigh = highs[ArrayMaximum(highs)];
            m_asianLow  = lows[ArrayMinimum(lows)];
            
            // Mark calculation as done for this day
            m_lastCalculationDay = dt.day_of_year;
            
            // --- VISUAL DEBUG: Draw the Box on the chart ---
            DrawDebugBox(timeAsianStart, timeAsianEnd, m_asianHigh, m_asianLow);
            
            CLogger::Debug(StringFormat("Asian Box Defined | High: %.5f | Low: %.5f", m_asianHigh, m_asianLow));
         }
      }
   }
   
   void DrawDebugBox(datetime t1, datetime t2, double priceHigh, double priceLow) {
      string objName = "AsianBox_" + TimeToString(t1);
      
      // Create the Rectangle Object
      if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, t1, priceHigh, t2, priceLow)) {
         // Style settings
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue); // Blue color
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);   // Solid line
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);             // Line thickness
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);           // Draw in background
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);          // No fill
         
         // Force chart update
         ChartRedraw(0);
      }
   }
};