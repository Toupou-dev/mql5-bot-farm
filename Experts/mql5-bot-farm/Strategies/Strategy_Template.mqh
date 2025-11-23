//+------------------------------------------------------------------+
//|                                            Strategy_Template.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Empty Template for a new strategy                   |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"

class CStrategyTemplate : public CStrategyBase {
private:
   //--- INSERT YOUR INDICATOR HANDLES HERE
   int m_handleMA; 
   int m_handleATR;
   
   //--- INSERT YOUR BUFFERS HERE
   double m_bufferMA[];
   double m_bufferATR[];

public:
   //--- Constructor: Pass params from the Main Bot to here
   CStrategyTemplate(string symbol, int period) 
      : CStrategyBase(symbol, period) {
      
      // Set arrays as series (Index 0 = Current Candle)
      ArraySetAsSeries(m_bufferMA, true);
      ArraySetAsSeries(m_bufferATR, true);
   }
   
   //--- 1. INITIALIZATION (Run once)
   virtual bool OnInitStrategy() override {
      // Define your indicators here
      m_handleMA  = iMA(m_symbol, (ENUM_TIMEFRAMES)m_period, 50, 0, MODE_SMA, PRICE_CLOSE);
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, 14);
      
      if(m_handleMA == INVALID_HANDLE || m_handleATR == INVALID_HANDLE) {
         return false;
      }
      return true;
   }
   
   //--- 2. UPDATE (Run every tick)
   virtual void OnTickStrategy() override {
      // Update data from indicators
      CopyBuffer(m_handleMA, 0, 0, 3, m_bufferMA);
      CopyBuffer(m_handleATR, 0, 0, 1, m_bufferATR);
   }
   
   //--- 3. LOGIC (The Brain)
   virtual int GetEntrySignal() override {
      // Write your BUY/SELL logic here
      // Return 1 for BUY
      // Return -1 for SELL
      // Return 0 for WAIT
      
      return 0; // Default: Do nothing
   }
   
   //--- 4. RISK: STOP LOSS DISTANCE
   virtual double GetStopLossDistance() override {
      // Example: Return 1.5x ATR
      if(ArraySize(m_bufferATR) > 0) {
         return m_bufferATR[0] * 1.5;
      }
      return 0.0;
   }
   
   //--- 5. RISK: TAKE PROFIT DISTANCE
   virtual double GetTakeProfitDistance(double slDistance) override {
      // Example: Risk Reward 1:2
      return slDistance * 2.0;
   }
};