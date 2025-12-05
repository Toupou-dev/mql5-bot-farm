//+------------------------------------------------------------------+
//|                                            Main_MeanRevBot.mq5   |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Mean Reversion Bot (EURGBP/AUDCAD)                  |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5"
#property version   "1.00"

//--- INCLUDES
#include "Core/Engine.mqh"
#include "Strategies/Strategy_MeanReversion.mqh"

//--- INPUTS: GLOBAL RISK SETTINGS
input group    "--- GLOBAL RISK SETTINGS ---"
input double   Inp_RiskPercent     = 1.0;      // Risk per trade
input double   Inp_MaxDailyLoss    = 4.5;      // Daily Loss Limit
input double   Inp_MaxTotalDD      = 9.5;      // Total Loss Limit
input bool     Inp_StopOnObjective = false;    // FALSE for Range trading (we want multiple trades)

//--- INPUTS: STRATEGY INDICATORS
input group    "--- STRATEGY INDICATORS ---"
input int      Inp_MagicNumber     = 6060;     // Unique ID (Must be different from GoldBot)
input int      Inp_BB_Period       = 20;       // Bollinger Period
input double   Inp_BB_Deviation    = 2.5;      // Deviation (2.0 to 3.0)
input int      Inp_RSI_Period      = 14;       // RSI Period
input int      Inp_RSI_Overbought  = 70;       // Sell Level
input int      Inp_RSI_Oversold    = 30;       // Buy Level

//--- INPUTS: STRATEGY FINE TUNING
input group    "--- STRATEGY FINE TUNING ---"
input int      Inp_ATR_Period      = 14;       // ATR Period
input double   Inp_ATR_Multiplier  = 2.0;      // SL Distance (Needs to be wide for Mean Rev)
input double   Inp_RiskRewardRatio = 1.0;      // TP Ratio (1:1 is common for Range)
input int      Inp_Min_SL_Points   = 100;      // Min SL (10 pips for Forex)

//--- INPUTS: TIME FILTERS
input group    "--- TIME FILTERS ---"
input string   Inp_StartTime       = "01:00";  // Asian Session is great for Range!
input string   Inp_EndTime         = "20:00";  // Stop before US close volatility
input bool     Inp_EnableHardClose = false;    // Range trades can last overnight
input string   Inp_ForceCloseTime  = "23:00";  // Not used if above is false

//--- INPUTS: MANAGEMENT
input group    "--- MANAGEMENT ---"
input double   Inp_BE_Trigger_RR   = 0.5;      // Secure quickly
input int      Inp_BE_Offset_Points= 5;        // Cover spread (0.5 pips)
input bool     Inp_UseTrailing     = false;    // Usually false for strict Mean Rev
input int      Inp_Trail_Start     = 0;
input int      Inp_Trail_Dist      = 0;
input int      Inp_Trail_Step      = 0;
input int      Inp_MaxSpreadPoints = 30;       // Max Spread (3 pips)
input bool     Inp_DebugMode       = false;

//--- GLOBAL OBJECTS
CEngine engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //--- 1. Create the Strategy
   CStrategyBase* strategy = new CStrategyMeanReversion(
      _Symbol, 
      Period(), 
      Inp_BB_Period,
      Inp_BB_Deviation,
      Inp_RSI_Period,
      Inp_RSI_Overbought,
      Inp_RSI_Oversold,
      Inp_ATR_Period,
      Inp_ATR_Multiplier,
      Inp_RiskRewardRatio,
      Inp_Min_SL_Points
   );
   
   //--- 2. Initialize the Engine
   engine.Init(strategy, 
               Inp_MagicNumber, 
               Inp_RiskPercent, 
               Inp_MaxDailyLoss, 
               Inp_MaxTotalDD, 
               Inp_StartTime, 
               Inp_EndTime,
               Inp_ForceCloseTime,
               Inp_BE_Trigger_RR,
               Inp_BE_Offset_Points,
               Inp_DebugMode,
               Inp_StopOnObjective,
               Inp_EnableHardClose,
               Inp_UseTrailing,
               Inp_Trail_Start,
               Inp_Trail_Dist,
               Inp_Trail_Step,
               Inp_MaxSpreadPoints
               ); 
   
   EventSetTimer(60);
   return(INIT_SUCCEEDED);
}

void OnTick() { engine.OnTick(); }
void OnTimer() { engine.OnTimer(); }
void OnDeinit(const int reason) { EventKillTimer(); }