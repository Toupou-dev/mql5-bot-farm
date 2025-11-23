//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Centralized logging system with Debug toggling.     |
//+------------------------------------------------------------------+
#property strict

class CLogger {
private:
   static bool s_debugMode; // Static flag shared across the whole bot

public:
   //+------------------------------------------------------------------+
   //| Enable or Disable detailed debug logs                            |
   //+------------------------------------------------------------------+
   static void SetDebugMode(bool enable) {
      s_debugMode = enable;
   }

   //+------------------------------------------------------------------+
   //| Standard Info Log (Always visible)                               |
   //+------------------------------------------------------------------+
   static void Log(string msg) {
      Print("[INFO]  ", msg);
   }
   
   //+------------------------------------------------------------------+
   //| Warning/Error Log (Always visible + Distinctive)                 |
   //+------------------------------------------------------------------+
   static void Error(string msg) {
      Print("[ERROR] --------------------------------------------------");
      Print("[ERROR] ", msg);
      Print("[ERROR] --------------------------------------------------");
   }
   
   //+------------------------------------------------------------------+
   //| Trade Action Log (Always visible)                                |
   //+------------------------------------------------------------------+
   static void Trade(string action, double price, double lots, string extraInfo="") {
      string msg = StringFormat("[TRADE] %s | Price: %.5f | Lots: %.2f", action, price, lots);
      if(extraInfo != "") msg += " | " + extraInfo;
      Print(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Debug Log (Only visible if Inp_DebugMode = true)                 |
   //| Use this for high-frequency logs (OnTick details)                |
   //+------------------------------------------------------------------+
   static void Debug(string msg) {
      if(s_debugMode) {
         Print("[DEBUG] ", msg);
      }
   }
};

// Initialize static member
bool CLogger::s_debugMode = false;