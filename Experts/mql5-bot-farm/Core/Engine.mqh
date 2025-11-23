//+------------------------------------------------------------------+
//|                                                       Engine.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//+------------------------------------------------------------------+
#include "PropGuardian.mqh"
#include "TradeManager.mqh"
#include "RiskManager.mqh"
#include "../Utils/TimeFilters.mqh"
#include "../Strategies/StrategyBase.mqh"

class CEngine {
private:
   CPropGuardian* m_guardian;
   CTradeManager* m_tradeMgr;
   CRiskManager*  m_riskMgr;
   CTimeFilter*   m_timeFilter;
   CStrategyBase* m_strategy;
   
   double m_riskPercent;
   int    m_forceCloseMinutes;
   bool   m_isClosedForDay;
   
   // BE Settings
   double m_beTriggerRR;
   double m_beOffsetPoints;

   //--- Trade management toggles
   bool m_stopOnObjective; // If true, stop after TP or 
   bool   m_enableForceClose; // NEW: Enable/Disable end of day close
   //--- Trailing Stop Settings
   bool   m_useTrailing;      // NEW: Enable Trailing
   double m_trailingStart;    // Start trailing when profit > X points
   double m_trailingDist;     // Keep SL at X points distance
   double m_trailingStep;     // Update SL every X points

public:
   CEngine() {}
   
   ~CEngine() {
      if(CheckPointer(m_guardian)   == POINTER_DYNAMIC) delete m_guardian;
      if(CheckPointer(m_tradeMgr)   == POINTER_DYNAMIC) delete m_tradeMgr;
      if(CheckPointer(m_riskMgr)    == POINTER_DYNAMIC) delete m_riskMgr;
      if(CheckPointer(m_timeFilter) == POINTER_DYNAMIC) delete m_timeFilter;
      if(CheckPointer(m_strategy)   == POINTER_DYNAMIC) delete m_strategy;
   }

   void Init(CStrategyBase* strategy, int magic, double risk, double maxDailyDD, double maxTotalDD, 
             string startT, string endT, string forceCloseT,
             double beTriggerRR, int beOffsetPoints, bool debugMode, bool stopOnObjective,bool enableForceClose,
             bool useTrailing, int trailStartPoints, int trailDistPoints, int trailStepPoints) // <--- Added DebugMode
   { 
      // Set Global Logger Debug Mode
      CLogger::SetDebugMode(debugMode);
      
      m_strategy    = strategy;
      m_riskPercent = risk;
      m_beTriggerRR = beTriggerRR;
      m_beOffsetPoints = beOffsetPoints * Point();
      
      m_guardian    = new CPropGuardian(maxDailyDD, maxTotalDD);
      m_tradeMgr    = new CTradeManager(magic);
      m_riskMgr     = new CRiskManager();
      m_timeFilter  = new CTimeFilter(startT, endT);
      
      m_forceCloseMinutes = TimeStringToMinutes(forceCloseT);
      m_isClosedForDay    = false;

      m_stopOnObjective = stopOnObjective;

      m_enableForceClose = enableForceClose;
      
      m_useTrailing   = useTrailing;
      m_trailingStart = trailStartPoints * Point();
      m_trailingDist  = trailDistPoints  * Point();
      m_trailingStep  = trailStepPoints  * Point();
      
      if(!m_strategy.OnInitStrategy()) {
         CLogger::Error("Strategy Initialization Failed!");
      } else {
         CLogger::Log("Engine Initialized. Waiting for ticks...");
      }
   }

   void OnTick() {
      // 1. FORCE CLOSE LOGIC
      if(m_enableForceClose && IsForceCloseTime()){
         if(!m_isClosedForDay) {
            CLogger::Log("Force Close Time reached. Executing End-of-Day sequence.");
            m_tradeMgr.DeleteAllPendingOrders();
            m_tradeMgr.CloseAllPositions();
            m_isClosedForDay = true;
         }
         return;
      }
      
      if(m_isClosedForDay && !IsForceCloseTime()) {
         CLogger::Log("New Day Detected. Resetting Close Flag.");
         m_isClosedForDay = false;
      }
   
      // 2. STRATEGY UPDATE
      m_strategy.OnTickStrategy();
      if(!m_guardian.IsSafeToTrade()) return;
      ManageBreakeven();
      if(m_useTrailing) ManageTrailing();

      // 3. NEW: CHECK DAILY WIN RULE
      // We only check this if we have NO open positions (looking for new entry)
      if(PositionsTotal() == 0 && m_stopOnObjective) {
         if(m_tradeMgr.HasDailyWin()) {
            // Optional: Log once per minute to avoid spam, or just return silently
            // CLogger::Debug("Objective reached (TP/BE). Trading stopped for the day.");
            return; // <--- STOP HERE. No new trades will be taken.
         }
      }

      // 4. ENTRY LOGIC
      if(!m_timeFilter.IsTradingTime()) return;
      if(PositionsTotal() > 0) return; 
      
      int signal = m_strategy.GetEntrySignal();
      if(signal != 0) {
         CLogger::Debug("Signal Detected: " + IntegerToString(signal));
         ExecuteSignal(signal);
      }
   }
   
   void OnTimer() {
      m_guardian.UpdateDailyBalance();
   }

private:
   void ManageBreakeven() {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC) != m_tradeMgr.RequestMagic()) continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
         long type        = PositionGetInteger(POSITION_TYPE);
         
         // Logging specific for debugging BE logic
         // (Only logs if DebugMode is true)
         
         if(type == POSITION_TYPE_BUY) {
            double newSL = openPrice + m_beOffsetPoints;
            if(currentSL >= newSL - _Point) continue; // Already at BE
            
            double riskDist = openPrice - currentSL;
            double trigger  = openPrice + (riskDist * m_beTriggerRR);
            
            // Check Trigger
            if(curPrice >= trigger) {
               CLogger::Log(StringFormat("BE Triggered (BUY) | Price: %.5f >= Trigger: %.5f | Move SL to %.5f", curPrice, trigger, newSL));
               m_tradeMgr.ModifySL(ticket, newSL);
            }
         }
         else if(type == POSITION_TYPE_SELL) {
            double newSL = openPrice - m_beOffsetPoints;
            if(currentSL > 0 && currentSL <= newSL + _Point) continue; 
            
            double riskDist = currentSL - openPrice;
            double trigger  = openPrice - (riskDist * m_beTriggerRR);
            
            if(curPrice <= trigger) {
               CLogger::Log(StringFormat("BE Triggered (SELL) | Price: %.5f <= Trigger: %.5f | Move SL to %.5f", curPrice, trigger, newSL));
               m_tradeMgr.ModifySL(ticket, newSL);
            }
         }
      }
   }

   void ExecuteSignal(int direction) {
      double slDist = m_strategy.GetStopLossDistance();
      double tpDist = m_strategy.GetTakeProfitDistance(slDist);
      
      // Debug Risk Calculation
      CLogger::Debug("Calculating Entry... SL Dist: " + DoubleToString(slDist, 5) + " TP Dist: " + DoubleToString(tpDist, 5));

      if(slDist <= 0.0) {
         CLogger::Error("Invalid SL Distance received from strategy.");
         return;
      }

      double lot = m_riskMgr.GetLotSize(m_riskPercent, slDist, _Symbol);
      CLogger::Debug("Calculated Lot Size: " + DoubleToString(lot, 2) + " for Risk: " + DoubleToString(m_riskPercent, 1) + "%");
      
      if(lot <= 0.0) return;
      
      double openPrice, slPrice, tpPrice;
      
      if(direction == 1) { 
         openPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         slPrice   = openPrice - slDist;
         tpPrice   = openPrice + tpDist;
         m_tradeMgr.OpenBuy(lot, slPrice, tpPrice, "Farm_Bot_Buy");
      }
      else if(direction == -1) { 
         openPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         slPrice   = openPrice + slDist;
         tpPrice   = openPrice - tpDist;
         m_tradeMgr.OpenSell(lot, slPrice, tpPrice, "Farm_Bot_Sell");
      }
   }
   
   bool IsForceCloseTime() {
      MqlDateTime dt;
      TimeCurrent(dt);
      int currentMinutes = (dt.hour * 60) + dt.min;
      return (currentMinutes >= m_forceCloseMinutes);
   }

   int TimeStringToMinutes(string timeStr) {
      string sep[];
      StringSplit(timeStr, ':', sep);
      if(ArraySize(sep) < 2) return 1439; 
      return ((int)StringToInteger(sep[0]) * 60) + (int)StringToInteger(sep[1]);
   }

   //+------------------------------------------------------------------+
   //| Logic: Trailing Stop (Follow the price)                          |
   //+------------------------------------------------------------------+
   void ManageTrailing() {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC) != m_tradeMgr.RequestMagic()) continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
         long type        = PositionGetInteger(POSITION_TYPE);
         
         if(type == POSITION_TYPE_BUY) {
            // 1. Check if we are in profit enough to start trailing
            if(curPrice - openPrice < m_trailingStart) continue;
            
            // 2. Calculate theoretical SL
            double newSL = curPrice - m_trailingDist;
            
            // 3. Move only if new SL is higher than current SL + Step
            if(newSL > currentSL + m_trailingStep) {
               m_tradeMgr.ModifySL(ticket, newSL);
               CLogger::Debug("Trailing Stop Update (BUY) -> " + DoubleToString(newSL, 5));
            }
         }
         else if(type == POSITION_TYPE_SELL) {
            // 1. Check profit
            if(openPrice - curPrice < m_trailingStart) continue;
            
            // 2. Calculate theoretical SL
            double newSL = curPrice + m_trailingDist;
            
            // 3. Move only if new SL is lower than current SL - Step
            if(currentSL == 0 || newSL < currentSL - m_trailingStep) {
               m_tradeMgr.ModifySL(ticket, newSL);
               CLogger::Debug("Trailing Stop Update (SELL) -> " + DoubleToString(newSL, 5));
            }
         }
      }
   }
};