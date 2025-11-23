//+------------------------------------------------------------------+
//|                                      Strategy_GoldBreakout.mqh   |
//|                                      Copyright 2025, Expert MQL5 |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"

class CStrategyGoldBreakout : public CStrategyBase {
private:
   //--- Parameters
   int      m_breakoutPeriod;
   int      m_atrPeriod;
   double   m_atrMultiplier;     // For SL calculation
   int      m_trendMaPeriod;
   
   //--- NEW PARAMETERS
   double   m_riskRewardRatio;   // Target Profit relative to SL (e.g., 2.0, 3.0)
   double   m_breakoutOffset;    // Buffer points added to High/Low (e.g., 50 points)
   double   m_minSLDistance;     // Minimum SL distance allowed (Safety floor)
   
   //--- Indicators & Buffers
   int      m_handleATR;
   int      m_handleMA;
   double   m_atrBuffer[];
   double   m_maBuffer[];
   double   m_highBuffer[];
   double   m_lowBuffer[];
   double   m_closeBuffer[];
   
   

public:
   //+------------------------------------------------------------------+
   //| Constructor: Updated with new inputs                             |
   //+------------------------------------------------------------------+
   CStrategyGoldBreakout(string symbol, int period, 
                         int breakPer, int atrPer, double atrMult, 
                         double rrRatio, double offsetPoints, int minSLPoints,  int trendMaPeriod) 
      : CStrategyBase(symbol, period) {
      
      m_breakoutPeriod  = breakPer;
      m_atrPeriod       = atrPer;
      m_atrMultiplier   = atrMult;
      
      //--- Store new params
      m_riskRewardRatio = rrRatio;
      m_breakoutOffset  = offsetPoints * SymbolInfoDouble(symbol, SYMBOL_POINT); // Convert to price
      m_minSLDistance   = minSLPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_trendMaPeriod   = trendMaPeriod;
      
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_maBuffer, true);
      ArraySetAsSeries(m_highBuffer, true);
      ArraySetAsSeries(m_lowBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);
   }
   
   virtual bool OnInitStrategy() override {
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, m_atrPeriod);
      
      //--- Initialize Trend Filter (SMA)
      m_handleMA  = iMA(m_symbol, (ENUM_TIMEFRAMES)m_period, m_trendMaPeriod, 0, MODE_SMA, PRICE_CLOSE);

      if(m_handleATR == INVALID_HANDLE || m_handleMA == INVALID_HANDLE) {
         return false;
      }
      return true;
   }
   
   virtual void OnTickStrategy() override {
      CopyBuffer(m_handleATR, 0, 0, 1, m_atrBuffer);
      CopyBuffer(m_handleMA,  0, 0, 1, m_maBuffer);

      int count = m_breakoutPeriod + 2;
      CopyHigh(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, count, m_highBuffer);
      CopyLow(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, count, m_lowBuffer);
      CopyClose(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, count, m_closeBuffer);
   }
   
   virtual int GetEntrySignal() override {
      if(ArraySize(m_highBuffer) < m_breakoutPeriod + 1) return 0;
      
      double lastClose = m_closeBuffer[1];
      double trendMA   = m_maBuffer[0];
      
      // Find High/Low of previous range
      double highestHigh = -DBL_MAX;
      double lowestLow   = DBL_MAX;
      
      for(int i = 2; i <= m_breakoutPeriod + 1; i++) {
         if(m_highBuffer[i] > highestHigh) highestHigh = m_highBuffer[i];
         if(m_lowBuffer[i] < lowestLow)    lowestLow   = m_lowBuffer[i];
      }
      
      //--- APPLY OFFSET LOGIC
      // We add the offset to the High (harder to break up)
      // We subtract the offset from the Low (harder to break down)
      
      //--- BUY SIGNAL
      // 1. Breakout confirmed
      // 2. AND Price is ABOVE the Trend MA (Bullish Context)
      if(lastClose > (highestHigh + m_breakoutOffset)) {
         if(lastClose > trendMA) { 
            return 1; 
         }
      }
      
      //--- SELL SIGNAL
      // 1. Breakout confirmed
      // 2. AND Price is BELOW the Trend MA (Bearish Context)
      if(lastClose < (lowestLow - m_breakoutOffset)) {
         if(lastClose < trendMA) { 
            return -1; 
         }
      }
      
      return 0; 
   }
   
   virtual double GetStopLossDistance() override {
       if(ArraySize(m_atrBuffer) < 1) return 0.0;
       double slDist = m_atrBuffer[0] * m_atrMultiplier;
       if(slDist < m_minSLDistance) slDist = m_minSLDistance;
       return slDist;
   }

   virtual double GetTakeProfitDistance(double slDistance) override {
      return slDistance * m_riskRewardRatio; 
   }
};