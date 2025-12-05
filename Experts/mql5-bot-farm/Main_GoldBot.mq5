//+------------------------------------------------------------------+
//|                                                 Main_GoldBot.mq5 |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Launcher for the Gold Breakout Strategy             |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5"
#property version   "1.00"

//--- INCLUDES
#include "Core/Engine.mqh"
#include "Strategies/Strategy_GoldBreakout.mqh"

//--- INPUTS: GLOBAL RISK SETTINGS
input group    "--- GLOBAL RISK SETTINGS ---"
input double   Inp_RiskPercent     = 1.0;      // Risk per trade (%)
input double   Inp_MaxDailyDD      = 4.5;      // Max Daily Loss (%)
input double   Inp_MaxTotalDD      = 9.5;      // Max Total Drawdown (%)
input bool     Inp_StopOnObjective = true;     // Stop trading after a Win (TP) or BE?

//--- INPUTS: STRATEGY PARAMETERS
input group    "--- STRATEGY INDICATORS ---"
input int      Inp_MagicNumber     = 5050;     // Unique ID
input int      Inp_BreakoutPeriod  = 20;       // Donchian Period (Breakout Period)
input int      Inp_ATR_Period      = 14;       // ATR Period
input int      Inp_Trend_MA_Period = 100;     // Trend MA Period

//--- INPUTS: STRATEGY FINE TUNING
input group    "--- STRATEGY FINE TUNING ---"
input double   Inp_ATR_Multiplier  = 1.5;      // SL = ATR * X
input double   Inp_RiskRewardRatio = 2.0;      // RRR TP = SL * X
input double   Inp_BreakoutOffset  = 20.0;     // Breakout Buffer (Points)
input int      Inp_Min_SL_Points   = 200;      // Min SL (Points)

//--- INPUTS: TIME FILTERS
input group    "--- TIME FILTERS ---"
input string   Inp_StartTime       = "09:00";  // Start Trading (HH:MM)
input string   Inp_EndTime         = "18:00";  // Stop Opening New Trades (HH:MM)
input string   Inp_ForceCloseTime  = "21:30";  // HARD STOP: Close all positions & Pending Orders
input bool     Inp_EnableHardClose = true;     // Enable HARD CLOSE at Force Close Time

input group    "--- BREAKEVEN SETTINGS ---"
input double   Inp_BE_Trigger_RR   = 1.0;      // Move to BE when profit = Risk * X (e.g. 1.0)
input int      Inp_BE_Offset_Points= 10;       // Points to add to BE (cover fees)

input group    "--- TRAILING STOP ---"
input bool     Inp_UseTrailing     = false;    // Set TRUE for Swing
input int      Inp_Trail_Start     = 500;      // Start after X points profit
input int      Inp_Trail_Dist      = 300;      // Keep SL X points behind
input int      Inp_Trail_Step      = 50;       // Move every X points

input group    "--- DEBUGGING ---"
input bool     Inp_DebugMode       = true;     // Enable detailed logs in Journal



//--- GLOBAL OBJECTS
CEngine engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //--- 1. Create Strategy Instance
   CStrategyBase* strategy = new CStrategyGoldBreakout(
      _Symbol, 
      Period(), 
      Inp_BreakoutPeriod, 
      Inp_ATR_Period, 
      Inp_ATR_Multiplier,
      Inp_RiskRewardRatio, 
      Inp_BreakoutOffset,
      Inp_Min_SL_Points,
      Inp_Trend_MA_Period
   );
   
   //--- 2. Initialize Engine
   engine.Init(strategy, 
               Inp_MagicNumber, 
               Inp_RiskPercent, 
               Inp_MaxDailyDD, 
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
               Inp_Trail_Step 
            );
   
   //--- 3. Set Daily Timer
   EventSetTimer(60);
   
   Print("[INFO] Breakeven Logic Active. Trigger at R:", DoubleToString(Inp_BE_Trigger_RR, 1));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   engine.OnTick();
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   engine.OnTimer();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
}