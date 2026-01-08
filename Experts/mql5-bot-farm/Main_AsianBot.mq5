//+------------------------------------------------------------------+
//|                                            Main_AsianBot.mq5     |
//|                                      Copyright 2025, Expert MQL5 |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5"
#property version   "1.00"

//--- INCLUDES
#include "Core/Engine.mqh"
#include "Strategies/Strategy_TimeBreakout.mqh" 

//--- INPUTS: GLOBAL RISK SETTINGS
input group    "--- GLOBAL RISK SETTINGS ---"
input double   Inp_RiskPercent     = 0.5;      // Risk per Trade %
input double   Inp_MaxDailyDD      = 1;      // Max Daily Loss (%) 
input double   Inp_MaxTotalDD      = 9.5;      // Max Total Drawdown (%)
input bool     Inp_StopOnObjective = true;     // Stop trading after a Win (TP) or BE?

//--- INPUTS: STRATEGY SETTINGS (BOX)
input group    "--- STRATEGY BOX TIME ---"
input int      Inp_MagicNumber     = 7070;     // Magic Number
input int      Inp_BoxStart_Hour   = 1;        // Box Start Hour (01:00)
input int      Inp_BoxStart_Min    = 0;        // Box Start Minute (00)
input int      Inp_BoxEnd_Hour     = 8;        // Box End Hour (08:00)
input int      Inp_BoxEnd_Min      = 0;        // Box End Minute (00)
input int      Inp_TrendMA         = 200;      // Trend Filter

//--- INPUTS: FINE TUNING
input group    "--- FINE TUNING ---"
input double   Inp_ATR_Multiplier  = 1.5;      // SL multiplier based on ATR
input double   Inp_RR_Ratio        = 2.0;      // RR Ratio
input int      Inp_Offset_Points   = 20;       // Breakout Confirmation (2 pips)
input int      Inp_Min_SL_Points   = 100;      // Minimum SL pips

//--- INPUTS: TIME EXECUTION
input group    "--- EXECUTION WINDOW ---"
input string   Inp_StartTime       = "09:00";  // Start entering trades after this time
input string   Inp_EndTime         = "12:00";  // Stop entering trades after this time
input bool     Inp_EnableHardClose = true;     // Force close all trades at night?
input string   Inp_ForceCloseTime  = "21:30";  // Hard Close Time

//--- INPUTS: BREAKEVEN SETTINGS
input group    "--- BREAKEVEN SETTINGS ---"
input double   Inp_BE_Trigger_RR   = 1.0;      // Move to BE when profit = Risk * X
input int      Inp_BE_Offset_Points= 10;       // Points to add to BE

//--- INPUTS: TRAILING STOP SETTINGS
input group    "--- TRAILING STOP ---"
input bool     Inp_UseTrailing     = false;    // False for DayTrading
input int      Inp_Trail_Start     = 500;      
input int      Inp_Trail_Dist      = 300;      
input int      Inp_Trail_Step      = 50;       

//--- INPUTS: MISC SETTINGS
input group    "--- MISC ---"
input int      Inp_MaxSpreadPoints = 30;       // Max Spread allowed
input bool     Inp_DebugMode       = true;     // Enable logs

CEngine engine;

int OnInit() {
   //--- 1. Create Strategy Instance
   CStrategyBase* strategy = new CStrategyTimeBreakout(
      _Symbol, Period(), 
      Inp_BoxStart_Hour, Inp_BoxStart_Min, // Début Boîte
      Inp_BoxEnd_Hour,   Inp_BoxEnd_Min,   // Fin Boîte
      Inp_Offset_Points,
      Inp_TrendMA, 
      14, // ATR fix period
      Inp_ATR_Multiplier, 
      Inp_RR_Ratio, 
      Inp_Min_SL_Points
   );
   
   //--- 2. Init engine
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
   
   //--- 3. Timer for daily reset
   EventSetTimer(60);
   
   return(INIT_SUCCEEDED);
}

void OnTick() {
   engine.OnTick();
}

void OnTimer() {
   engine.OnTimer();
}

void OnDeinit(const int reason) {
   EventKillTimer();
}