//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Wrapper for Trade Execution with detailed Logging.  |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/DealInfo.mqh>
#include "../Utils/Logger.mqh"

class CTradeManager : public CTrade
{
private:
   CDealInfo m_dealInfo;

public:
   CTradeManager(int magic)
   {
      this.SetExpertMagicNumber(magic);
      this.SetMarginMode();
      this.SetTypeFillingBySymbol(Symbol());
      this.SetDeviationInPoints(10);
   }

   bool OpenBuy(double vol, double slPrice, double tpPrice, string comment = "")
   {
      CLogger::Debug("Attempting BUY... Vol: " + DoubleToString(vol, 2) + " SL: " + DoubleToString(slPrice, 5));

      if (!this.Buy(vol, _Symbol, 0, slPrice, tpPrice, comment))
      {
         CLogger::Error("BUY Failed. RetCode: " + IntegerToString(this.ResultRetcode()) + " - " + this.ResultRetcodeDescription());
         return false;
      }

      CLogger::Trade("BUY EXEC", SymbolInfoDouble(_Symbol, SYMBOL_ASK), vol, "Ticket: " + IntegerToString(this.ResultOrder()));
      return true;
   }

   bool OpenSell(double vol, double slPrice, double tpPrice, string comment = "")
   {
      CLogger::Debug("Attempting SELL... Vol: " + DoubleToString(vol, 2) + " SL: " + DoubleToString(slPrice, 5));

      if (!this.Sell(vol, _Symbol, 0, slPrice, tpPrice, comment))
      {
         CLogger::Error("SELL Failed. RetCode: " + IntegerToString(this.ResultRetcode()) + " - " + this.ResultRetcodeDescription());
         return false;
      }

      CLogger::Trade("SELL EXEC", SymbolInfoDouble(_Symbol, SYMBOL_BID), vol, "Ticket: " + IntegerToString(this.ResultOrder()));
      return true;
   }

   bool ModifySL(ulong ticket, double newSL)
   {
      double currentTP = PositionGetDouble(POSITION_TP);

      if (!this.PositionModify(ticket, newSL, currentTP))
      {
         CLogger::Error("Modify SL Failed for Ticket " + IntegerToString(ticket) + ". RetCode: " + IntegerToString(this.ResultRetcode()));
         return false;
      }

      CLogger::Trade("SL UPDATE", newSL, PositionGetDouble(POSITION_VOLUME), "Moved to BE | Ticket: " + IntegerToString(ticket));
      return true;
   }

   void DeleteAllPendingOrders()
   {
      int deletedCount = 0;
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if (OrderGetInteger(ORDER_MAGIC) == this.RequestMagic())
         {
            if (this.OrderDelete(ticket))
            {
               deletedCount++;
               CLogger::Debug("Deleted Pending Order #" + IntegerToString(ticket));
            }
         }
      }
      if (deletedCount > 0)
         CLogger::Log("Cleanup: Deleted " + IntegerToString(deletedCount) + " pending orders.");
   }

   void CloseAllPositions()
   {
      int closedCount = 0;
      for (int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if (PositionGetInteger(POSITION_MAGIC) == this.RequestMagic())
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if (this.PositionClose(ticket))
            {
               closedCount++;
               CLogger::Trade("FORCE CLOSE", PositionGetDouble(POSITION_PRICE_CURRENT), PositionGetDouble(POSITION_VOLUME), "P&L: " + DoubleToString(profit, 2));
            }
         }
      }
      if (closedCount > 0)
         CLogger::Log("Cleanup: Closed " + IntegerToString(closedCount) + " positions.");
   }

   //+------------------------------------------------------------------+
   //| NEW: Check if we already had a winning trade (TP or BE) today    |
   //| Returns true if a closed trade with Profit >= 0 exists.          |
   //+------------------------------------------------------------------+
   bool HasDailyWin()
   {
      // 1. Define the start of the day (00:00 Server Time)
      MqlDateTime dt;
      TimeCurrent(dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      datetime startOfDay = StructToTime(dt);

      // 2. Request History for today
      if (!HistorySelect(startOfDay, TimeCurrent()))
         return false;

      int deals = HistoryDealsTotal();

      // 3. Loop through history deals
      for (int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);

         // Filter: Only check deals for THIS bot (Magic Number)
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != this.RequestMagic())
            continue;

         // Filter: Only check "Exit" deals (Entry Out)
         if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

         // Filter: Exclude Balance operations (Deposits)
         if (HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_BUY &&
             HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_SELL)
            continue;

         // 4. Check Profit
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         double total = profit + swap + comm;

         // LOGIC: If Total Result >= 0, it means TP or BE.
         // We treat BE as a "Win" in the sense that we stop trading.
         if (total >= 0)
         {
            return true;
         }
      }

      return false; // No winning trade found today
   }
};
;