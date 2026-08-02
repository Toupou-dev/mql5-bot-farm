//+------------------------------------------------------------------+
//|                                                 PropGuardian.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//+------------------------------------------------------------------+
#property strict
#include "../Utils/Logger.mqh"

class CPropGuardian {
private:
   double m_dailyStartBalance;
   double m_initialAccountBalance;
   double m_maxDailyLossPct;
   double m_maxTotalDDPct;

public:
   CPropGuardian(double maxDailyLoss, double maxTotalDD) {
      m_maxDailyLossPct = maxDailyLoss;
      m_maxTotalDDPct   = maxTotalDD;
      m_initialAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      UpdateDailyBalance(); 
   }

   void UpdateDailyBalance()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      if (balance <= 0.0)
      {
         CLogger::Error("[GUARDIAN] Invalid account balance (0). Daily reset aborted.");
         return;
      }

      m_dailyStartBalance = balance;

      CLogger::Log(
          "[GUARDIAN] Daily Balance Reset -> " + DoubleToString(m_dailyStartBalance, 2));
   }

   bool IsSafeToTrade()
   {
      if (m_dailyStartBalance <= 0.0)
      {
         UpdateDailyBalance();

         if (m_dailyStartBalance <= 0.0)
         {
            CLogger::Error("[GUARDIAN] Unable to initialize daily balance.");
            return false;
         }
      }

      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

      // Calculate Drawdowns
      double dailyDrop = (m_dailyStartBalance - currentEquity) / m_dailyStartBalance * 100.0;
      double totalDrop = (m_initialAccountBalance - currentEquity) / m_initialAccountBalance * 100.0;
      
      // Detailed debug (Optional: only if drop > 1%)
      if(dailyDrop > 1.0 || totalDrop > 1.0) {
         CLogger::Debug(StringFormat("[RISK MON] Daily DD: %.2f%% | Total DD: %.2f%%", dailyDrop, totalDrop));
      }
      
      // Check Violations
      if(dailyDrop >= m_maxDailyLossPct) {
         CLogger::Error(StringFormat("VIOLATION: Daily Loss Limit Hit! (Current: %.2f%% / Max: %.2f%%)", dailyDrop, m_maxDailyLossPct));
         return false;
      }
      
      if(totalDrop >= m_maxTotalDDPct) {
         CLogger::Error(StringFormat("VIOLATION: Max Total DD Hit! (Current: %.2f%% / Max: %.2f%%)", totalDrop, m_maxTotalDDPct));
         return false;
      }
      
      return true;
   }
};