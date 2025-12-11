//+------------------------------------------------------------------+
//|                                            Main_AsianBot.mq5     |
//|                                      Copyright 2025, Expert MQL5 |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5"
#property version   "1.00"
#include "Core/Engine.mqh"
#include "Strategies/Strategy_AsianBreakout.mqh"

//--- INPUTS

//--- INPUTS: GLOBAL RISK SETTINGS
input group    "--- GLOBAL RISK SETTINGS ---"
input double   Inp_MaxDailyDD      = 1;      // Max Daily Loss (%)
input double   Inp_MaxTotalDD      = 9.5;      // Max Total Drawdown (%)
input bool     Inp_StopOnObjective = true;     // Stop trading after a Win (TP) or BE?

//--- INPUTS: STRATEGY SETTINGS
input group    "--- STRATEGY SETTINGS ---"
input int      Inp_MagicNumber     = 7070;     // Magic Number
input int      Inp_AsianStartHour  = 1;        // Box Start (01:00)
input int      Inp_AsianEndHour    = 8;        // Box End (08:00 - Just before London)
input int      Inp_TrendMA         = 200;      // Trend Filter

//--- INPUTS: RISK
input group    "--- RISK ---"
input double   Inp_RiskPercent     = 0.5;      // Risk per Trade %
input double   Inp_ATR_Multiplier  = 1.5;      // SL multiplier based on ATR
input double   Inp_RR_Ratio        = 2.0;      // RR Ratio
input int      Inp_Offset_Points   = 20;       // Breakout Confirmation (2 pips)
input int      Inp_Min_SL_Points   = 100;      // Minimum SL pips
input int      Inp_MaxSpreadPoints = 30;       // Max Spread allowed (points)

//--- INPUTS: TIME EXECUTION
input group    "--- EXECUTION WINDOW ---"
input string   Inp_StartTime      = "09:00";  // Start entering after
input string   Inp_EndTime        = "12:00";  // Stop entering after
input bool     Inp_EnableHardClose       = true;     // Force close all trades
input string   Inp_ForceCloseTime      = "21:30";  // Close before night

//--- INPUTS: BREAKEVEN SETTINGS
input group    "--- BREAKEVEN SETTINGS ---"
input double   Inp_BE_Trigger_RR   = 1.0;      // Move to BE when profit = Risk * X (e.g. 1.0)
input int      Inp_BE_Offset_Points= 10;       // Points to add to BE (cover fees)

//--- INPUTS: TRAILING STOP SETTINGS
input group    "--- TRAILING STOP ---"
input bool     Inp_UseTrailing     = false;    // Set TRUE for Swing
input int      Inp_Trail_Start     = 500;      // Start after X points profit
input int      Inp_Trail_Dist      = 300;      // Keep SL X points behind
input int      Inp_Trail_Step      = 50;       // Move every X points

//--- INPUTS: MISC SETTINGS
input group    "--- DEBUGGING ---"
input bool     Inp_DebugMode       = true;     // Enable detailed logs in Journal

CEngine engine;

int OnInit() {
   CStrategyBase* strategy = new CStrategyAsianBreakout(
      _Symbol, Period(), 
      Inp_AsianStartHour, Inp_AsianEndHour, Inp_Offset_Points,
      Inp_TrendMA, 14, Inp_ATR_Multiplier, Inp_RR_Ratio, Inp_Min_SL_Points
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
               Inp_Trail_Step,
               Inp_MaxSpreadPoints 
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