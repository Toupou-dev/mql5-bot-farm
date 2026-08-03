//+------------------------------------------------------------------+
//|                                      Main_TimeBreakoutBot.mq5    |
//|                                      Copyright 2026, Expert MQL5 |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5"
#property version   "1.00"

//--- INCLUDES
#include "Core/Engine.mqh"
#include "Strategies/Strategy_TimeBreakout.mqh"
//--- INPUTS: GLOBAL RISK
input group    "--- GLOBAL RISK SETTINGS ---"
input double   Inp_RiskPercent     = 0.5;      // Risk per Trade %
input double   Inp_MaxDailyDD      = 1.5;      // Max Daily Loss
input double   Inp_MaxTotalDD      = 9.9;      // Max Loss Overall
input bool     Inp_StopOnObjective = true;     // US30 is volatile, 1 good trade is enough
input string   Inp_SkipMonths = "";            // Skip Months (Comma-separated, 0-12, 0=Jan, 12=Dec)
input string   Inp_SkipDays   = "";            // Skip Days (Comma-separated, 0-6, 0=Sunday, 6=Saturday)

//--- INPUTS: STRATEGY BOX TIME (Local session)
input group    "--- STRATEGY BOX TIME ---"
input int      Inp_MagicNumber     = 3030;     // Magic Number
input string   Inp_TimeZone        = "HK";     // Time Zone for the local session
input int      Inp_BoxStart_Hour   = 9;        // Starting box hour in local zone
input int      Inp_BoxStart_Min    = 0;        // Starting box minute in local zone
input int      Inp_BoxEnd_Hour     = 9;        // Ending box hour in local zone
input int      Inp_BoxEnd_Min      = 15;       // Ending box minute in local zone
input int      Inp_TrendMA         = 50;       // Trend Filter (Shorter for indices)

//--- INPUTS: FINE TUNING (ADAPTÉ INDICES)
input group    "--- FINE TUNING ---"
input double   Inp_ATR_Multiplier  = 1.0;      // SL multiplier based on ATR
input double   Inp_RR_Ratio        = 2.0;      // RR Ratio
input int      Inp_Offset_Points   = 200;      // Breakout Confirmation (2 pips)
input int      Inp_Min_SL_Points   = 500;      // Minimum SL pips

//--- INPUTS: TIME EXECUTION
input group    "--- EXECUTION WINDOW ---"
input string   Inp_StartTime       = "15:45";  // Start entering trades after this time
input string   Inp_EndTime         = "18:00";  // Stop entering trades after this time
input bool     Inp_EnableHardClose = true;     // Force close all trades at night?
input string   Inp_ForceCloseTime  = "22:00";  // Hard Close Time

//--- INPUTS: BREAKEVEN & TRAILING
input group    "--- MANAGEMENT ---"
input double   Inp_BE_Trigger_RR   = 0.5;      // Move to BE when profit = Risk * X
input int      Inp_BE_Offset_Points= 50;       // Points to add to BE
input bool     Inp_UseTrailing     = true;     // Use Trailing Stop?
input int      Inp_Trail_Start     = 1000;     // Start trailing when profit > X points
input int      Inp_Trail_Dist      = 500;      // Keep SL at X points distance
input int      Inp_Trail_Step      = 100;      // Update SL every X points

//--- INPUTS: MISC
input group    "--- MISC ---"
input int      Inp_MaxSpreadPoints = 300;       // Max Spread allowed
input bool     Inp_DebugMode       = true;      // Enable logs

CEngine engine;

int OnInit() {
   // Création de la stratégie avec les heures/minutes spécifiques US30
   CStrategyBase* strategy = new CStrategyTimeBreakout(
      _Symbol, Period(), 
      Inp_TimeZone,
      Inp_BoxStart_Hour, Inp_BoxStart_Min, 
      Inp_BoxEnd_Hour,   Inp_BoxEnd_Min,   
      Inp_Offset_Points,
      Inp_TrendMA, 
      14, 
      Inp_ATR_Multiplier, 
      Inp_RR_Ratio, 
      Inp_Min_SL_Points
   );
   
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
               Inp_SkipMonths,
               Inp_SkipDays,
               Inp_EnableHardClose,
               Inp_UseTrailing,
               Inp_Trail_Start,
               Inp_Trail_Dist,
               Inp_Trail_Step,
               Inp_MaxSpreadPoints 
            );
   
   EventSetTimer(86400);
   return(INIT_SUCCEEDED);
}

void OnTick() { engine.OnTick(); }
void OnTimer() { engine.OnTimer(); }
void OnDeinit(const int reason) { EventKillTimer(); }