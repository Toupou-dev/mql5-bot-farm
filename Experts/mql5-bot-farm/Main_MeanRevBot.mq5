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
input double   Inp_RiskPercent     = 1.0;      // Risk per Trade (% of Account Balance)
input double   Inp_MaxDailyLoss    = 4.5;      // Max Daily Drawdown Limit (%)
input double   Inp_MaxTotalDD      = 9.5;      // Max Total Drawdown Limit (%)
input bool     Inp_StopOnObjective = false;    // Stop Trading after Daily Win? (True/False)

//--- INPUTS: STRATEGY INDICATORS
input group    "--- STRATEGY INDICATORS ---"
input int      Inp_MagicNumber     = 6060;     // EA Unique ID (Magic Number)
input int      Inp_BB_Period       = 20;       // Bollinger Bands: Period
input double   Inp_BB_Deviation    = 2.5;      // Bollinger Bands: Standard Deviation
input int      Inp_RSI_Period      = 14;       // RSI: Period
input int      Inp_RSI_Overbought  = 70;       // RSI: Overbought Threshold (Sell Level)
input int      Inp_RSI_Oversold    = 30;       // RSI: Oversold Threshold (Buy Level)

//--- INPUTS: STRATEGY FINE TUNING
input group    "--- STRATEGY FINE TUNING ---"
input int      Inp_ATR_Period      = 14;       // ATR: Period (Volatility Calc)
input double   Inp_ATR_Multiplier  = 2.0;      // Stop Loss Distance (Multiplier x ATR)
input double   Inp_RiskRewardRatio = 1.0;      // Take Profit Ratio (Multiple of SL Distance)
input int      Inp_Min_SL_Points   = 100;      // Minimum Stop Loss Distance (Points)

//--- INPUTS: TIME FILTERS
input group    "--- TIME FILTERS ---"
input string   Inp_StartTime       = "01:00";  // Trading Start Time (HH:MM)
input string   Inp_EndTime         = "20:00";  // New Entry Cut-off Time (HH:MM)
input bool     Inp_EnableHardClose = false;    // Enable Force Close at End Time?
input string   Inp_ForceCloseTime  = "23:00";  // Force Close Execution Time (HH:MM)

//--- INPUTS: MANAGEMENT
input group    "--- MANAGEMENT ---"
input double   Inp_BE_Trigger_RR   = 0.5;      // Breakeven Trigger (Risk Ratio, e.g. 0.5R)
input int      Inp_BE_Offset_Points= 5;        // Breakeven Offset (Points added to Entry)
input bool     Inp_UseTrailing     = false;    // Enable Trailing Stop?
input int      Inp_Trail_Start     = 0;        // Trailing: Activation Profit (Points)
input int      Inp_Trail_Dist      = 0;        // Trailing: Distance from Price (Points)
input int      Inp_Trail_Step      = 0;        // Trailing: Modification Step (Points)
input int      Inp_MaxSpreadPoints = 30;       // Max Allowed Spread (Points)
input bool     Inp_DebugMode       = false;    // Enable Debug Logs in Journal?

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