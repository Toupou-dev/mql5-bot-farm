//+------------------------------------------------------------------+
//|                                      Strategy_MeanReversion.mqh  |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Counter-Trend Strategy (Bollinger Bands + RSI)      |
//+------------------------------------------------------------------+
#include "StrategyBase.mqh"
#include "../Utils/Logger.mqh"

class CStrategyMeanReversion : public CStrategyBase {
private:
   //--- Parameters
   int      m_bbPeriod;          // Period for Bollinger Bands (e.g. 20)
   double   m_bbDeviation;       // Deviation (e.g. 2.0)
   int      m_rsiPeriod;         // Period for RSI (e.g. 14)
   int      m_rsiOverbought;     // Level to Sell (e.g. 70)
   int      m_rsiOversold;       // Level to Buy (e.g. 30)
   
   //--- Risk Parameters
   int      m_atrPeriod;         // Period for ATR calculation
   double   m_atrMultiplier;     // Multiplier for SL distance
   double   m_riskRewardRatio;   // Target TP relative to SL
   double   m_minSLDistance;     // Minimum SL in Price (Safety floor)
   
   //--- Indicator Handles
   int      m_handleBB;
   int      m_handleRSI;
   int      m_handleATR;
   
   //--- Data Buffers
   double   m_upperBand[];
   double   m_lowerBand[];
   double   m_rsiBuffer[];
   double   m_atrBuffer[];
   double   m_closeBuffer[]; // To check price close

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CStrategyMeanReversion(string symbol, int period, 
                          int bbPer, double bbDev, int rsiPer, int rsiOb, int rsiOs,
                          int atrPer, double atrMult, double rrRatio, int minSLPoints)
      : CStrategyBase(symbol, period) {
      
      m_bbPeriod        = bbPer;
      m_bbDeviation     = bbDev;
      m_rsiPeriod       = rsiPer;
      m_rsiOverbought   = rsiOb;
      m_rsiOversold     = rsiOs;
      m_atrPeriod       = atrPer;
      m_atrMultiplier   = atrMult;
      m_riskRewardRatio = rrRatio;
      m_minSLDistance   = minSLPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Enable Series Access (Index 0 = Current Candle)
      ArraySetAsSeries(m_upperBand, true);
      ArraySetAsSeries(m_lowerBand, true);
      ArraySetAsSeries(m_rsiBuffer, true);
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);
   }
   
   //+------------------------------------------------------------------+
   //| Initialization                                                   |
   //+------------------------------------------------------------------+
   virtual bool OnInitStrategy() override {
      // 1. Create Bollinger Bands
      m_handleBB = iBands(m_symbol, (ENUM_TIMEFRAMES)m_period, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
      
      // 2. Create RSI
      m_handleRSI = iRSI(m_symbol, (ENUM_TIMEFRAMES)m_period, m_rsiPeriod, PRICE_CLOSE);
      
      // 3. Create ATR (For Volatility-based Risk)
      m_handleATR = iATR(m_symbol, (ENUM_TIMEFRAMES)m_period, m_atrPeriod);
      
      // Check for errors
      if(m_handleBB == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE || m_handleATR == INVALID_HANDLE) {
         CLogger::Error("MeanReversion: Failed to create indicator handles.");
         return false;
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Data on Tick                                              |
   //+------------------------------------------------------------------+
   virtual void OnTickStrategy() override {
      // Copy BB Data (Buffer 1 = Upper, Buffer 2 = Lower)
      if(CopyBuffer(m_handleBB, 1, 0, 3, m_upperBand) < 0) return;
      if(CopyBuffer(m_handleBB, 2, 0, 3, m_lowerBand) < 0) return;
      
      // Copy RSI & ATR
      if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsiBuffer) < 0) return;
      if(CopyBuffer(m_handleATR, 0, 0, 1, m_atrBuffer) < 0) return;
      
      // Copy Price Close
      if(CopyClose(m_symbol, (ENUM_TIMEFRAMES)m_period, 0, 3, m_closeBuffer) < 0) return;
   }
   
   //+------------------------------------------------------------------+
   //| Entry Logic                                                      |
   //+------------------------------------------------------------------+
   virtual int GetEntrySignal() override {
      // Safety check on data
      if(ArraySize(m_upperBand) < 2 || ArraySize(m_rsiBuffer) < 2) return 0;
      
      // We look at Index 1 (Closed Candle) to confirm the signal
      double closePrice = m_closeBuffer[1]; 
      double rsiValue   = m_rsiBuffer[1];
      double upperBand  = m_upperBand[1];
      double lowerBand  = m_lowerBand[1];
      
      //--- BUY SIGNAL (Oversold Condition)
      // 1. Price closed BELOW the Lower Bollinger Band
      // 2. RSI is in Oversold territory (e.g. < 30)
      if(closePrice < lowerBand && rsiValue < m_rsiOversold) {
         CLogger::Debug(StringFormat("BUY Signal | Price: %.5f < Band: %.5f | RSI: %.2f", closePrice, lowerBand, rsiValue));
         return 1; 
      }
      
      //--- SELL SIGNAL (Overbought Condition)
      // 1. Price closed ABOVE the Upper Bollinger Band
      // 2. RSI is in Overbought territory (e.g. > 70)
      if(closePrice > upperBand && rsiValue > m_rsiOverbought) {
         CLogger::Debug(StringFormat("SELL Signal | Price: %.5f > Band: %.5f | RSI: %.2f", closePrice, upperBand, rsiValue));
         return -1;
      }
      
      return 0; // No signal
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management: Stop Loss                                       |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() override {
      if(ArraySize(m_atrBuffer) < 1) return 0.0;
      
      // Dynamic SL: ATR * Multiplier
      double slDist = m_atrBuffer[0] * m_atrMultiplier;
      
      // Enforce Minimum SL
      if(slDist < m_minSLDistance) slDist = m_minSLDistance;
      
      return slDist;
   }
   
   //+------------------------------------------------------------------+
   //| Risk Management: Take Profit                                     |
   //+------------------------------------------------------------------+
   virtual double GetTakeProfitDistance(double slDistance) override {
      // For Mean Reversion, Risk:Reward is often lower than Trend Following
      // Because the Win Rate is usually higher (> 60%)
      return slDistance * m_riskRewardRatio;
   }
};