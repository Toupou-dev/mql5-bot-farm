//+------------------------------------------------------------------+
//|                                     Strategy_MeanReversion.mqh   |
//|                                      Copyright 2026, Expert MQL5  |
//| Description: Active Mean Reversion for US30 (Increased Frequency)|
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"

class CStrategyMeanReversion : public CStrategyBase {
private:
   int      m_bbPeriod;          
   double   m_bbDeviation;       
   int      m_rsiPeriod;         
   int      m_rsiOverbought;     
   int      m_rsiOversold;
   
   double   m_atrMultiplier;     
   double   m_riskRewardRatio;   
   double   m_minSLDistance;
   
   int      m_handleBB, m_handleRSI, m_handleATR;
   double   m_upperBand[], m_lowerBand[], m_rsiBuffer[], m_atrBuffer[];
   double   m_closeBuffer[], m_highBuffer[], m_lowBuffer[];

public:
   CStrategyMeanReversion(string symbol, int period, 
                          int bbPer, double bbDev, int rsiPer, int rsiOb, int rsiOs,
                          int atrPer, double atrMult, double rrRatio, int minSLPoints)
      : CStrategyBase(symbol, period) {
      
      m_bbPeriod        = bbPer;
      m_bbDeviation     = bbDev;
      m_rsiPeriod       = rsiPer;
      m_rsiOverbought   = rsiOb;
      m_rsiOversold     = rsiOs;
      m_atrMultiplier   = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance   = minSLPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      ArraySetAsSeries(m_upperBand, true);
      ArraySetAsSeries(m_lowerBand, true);
      ArraySetAsSeries(m_rsiBuffer, true);
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);
      ArraySetAsSeries(m_highBuffer, true);
      ArraySetAsSeries(m_lowBuffer, true);
   }

   virtual bool OnInitStrategy() override {
      m_handleBB  = iBands(m_symbol, (ENUM_TIMEFRAMES)m_period, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
      m_handleRSI = iRSI(m_symbol, (ENUM_TIMEFRAMES)m_period, m_rsiPeriod, PRICE_CLOSE);
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, 14);
      
      return (m_handleBB != INVALID_HANDLE && m_handleRSI != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
   }
   
   virtual void OnTickStrategy() override {
      CopyBuffer(m_handleBB, 1, 0, 3, m_upperBand);
      CopyBuffer(m_handleBB, 2, 0, 3, m_lowerBand);
      CopyBuffer(m_handleRSI, 0, 0, 3, m_rsiBuffer);
      CopyBuffer(m_handleATR, 0, 0, 1, m_atrBuffer);
      CopyClose(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, 3, m_closeBuffer);
      CopyHigh(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, 3, m_highBuffer);
      CopyLow(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, 3, m_lowBuffer);
   }
   
   virtual int GetEntrySignal() override {
      if(ArraySize(m_rsiBuffer) < 2) return 0;
      
      // Checking last closed candle (index 1) for signals
      double lastRSI = m_rsiBuffer[1];
      double lastHigh = m_highBuffer[1];
      double lastLow  = m_lowBuffer[1];
      double lastClose = m_closeBuffer[1];
      
      //--- BUY SIGNAL (Oversold Condition)
      // 1. The lowest point of the candle has pierced the lower Bollinger Band
      // 2. The RSI is in the oversold zone (below 35 to increase frequency)
      // 3. The candle has closed with a wick or showing a sign of reversal
      if(lastLow < m_lowerBand[1] && lastRSI < m_rsiOversold) {
         if(lastClose > lastLow) return 1; 
      }
      
      //--- SELL SIGNAL (Overbought Condition)
      // 1. The highest point of the candle has pierced the upper Bollinger Band
      // 2. The RSI is in the overbought zone (above 65 to increase frequency)
      if(lastHigh > m_upperBand[1] && lastRSI > m_rsiOverbought) {
         if(lastClose < lastHigh) return -1;
      }
      
      return 0;
   }
   
   virtual double GetStopLossDistance() override {
      double sl = m_atrBuffer[0] * m_atrMultiplier;
      return (sl < m_minSLDistance) ? m_minSLDistance : sl;
   }
   
   virtual double GetTakeProfitDistance(double slDistance) override {
      return slDistance * m_riskRewardRatio;
   }
};