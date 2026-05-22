//+------------------------------------------------------------------+
//|                         Main_Bd_SupertrendMa_TimeBreakout.mq5    |
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
input double   Inp_MaxTotalDD      = 9.5;      
input bool     Inp_StopOnObjective = true;     // Stop if TP or BE

//--- INPUTS: STRATEGY BOX TIME (NY OPEN)
input group    "--- STRATEGY BOX TIME ---"
input int      Inp_MagicNumber     = 3030;     // Magic Number
input int      Inp_BoxStart_Hour   = 15;       // Starting box hour (15h)
input int      Inp_BoxStart_Min    = 30;       // Starting box min (30)
input int      Inp_BoxEnd_Hour     = 15;       // Ending box hour (15h)
input int      Inp_BoxEnd_Min      = 45;       // Ending box min (45) -> Range of 15 min
input int      Inp_TrendMA         = 50;       // Trend Filter (Shorter for indices)

//--- INPUTS: FILTERS (EMA M5 & SUPERTREND H1)
input group    "--- EXACT VIDEO FILTERS ---"
input double   Inp_Offset_Points   = 100;      // Entry Offset (Points)
input int      Inp_EMA_Fast        = 20;       // Fast EMA (M5)
input int      Inp_EMA_Slow        = 50;       // Slow EMA (M5)
input int      Inp_ST_Period       = 10;       // SuperTrend Period (H1)
input double   Inp_ST_Mult         = 3.0;      // SuperTrend Multiplier (H1)

//--- INPUTS: RISK MANAGEMENT
input group    "--- RISK SETTINGS ---"
input double   Inp_RR_Ratio        = 2.0;      // RR Ratio (Video: 2.0 for US30)
input int      Inp_Min_SL_Points   = 300;      // Minimum SL distance

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
   CStrategyBase* strategy = new CStrategyTimeBreakout(
      _Symbol, 
      _Period, 
      Inp_BoxStart_Hour, 
      Inp_BoxStart_Min, 
      Inp_BoxEnd_Hour,   
      Inp_BoxEnd_Min,   
      Inp_Offset_Points,
      Inp_EMA_Fast,     
      Inp_EMA_Slow,    
      Inp_ST_Period,    
      Inp_ST_Mult,     
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