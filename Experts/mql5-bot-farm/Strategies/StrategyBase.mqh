//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Abstract Base Class (Interface) for all strategies. |
//|              Defines the contract that every strategy must obey. |
//+------------------------------------------------------------------+
#property strict

class CStrategyBase {
protected:
   //--- Common properties accessible to derived strategy classes
   string m_symbol;  // Symbol to trade (e.g., "EURUSD", "US30")
   int    m_period;  // Timeframe (e.g., PERIOD_M15, PERIOD_H1)

public:
   //+------------------------------------------------------------------+
   //| Constructor: Sets basic parameters                               |
   //+------------------------------------------------------------------+
   CStrategyBase(string symbol, int period) {
      m_symbol = symbol;
      m_period = period;
   }
   
   //+------------------------------------------------------------------+
   //| Virtual Destructor: Ensures proper cleanup of derived classes    |
   //+------------------------------------------------------------------+
   virtual ~CStrategyBase() {}
   
   //--- PURE VIRTUAL METHODS -------------------------------------------
   // These methods must be implemented by any child class (e.g., Strategy_RSI)
   
   //+------------------------------------------------------------------+
   //| Initialize indicators and data structures. Returns true if OK.   |
   //+------------------------------------------------------------------+
   virtual bool OnInitStrategy() = 0;

   //+------------------------------------------------------------------+
   //| Called on every tick to update buffers and calculations.         |
   //+------------------------------------------------------------------+
   virtual void OnTickStrategy() = 0;

   //+------------------------------------------------------------------+
   //| Returns the trade direction: 1 (BUY), -1 (SELL), 0 (WAIT)        |
   //+------------------------------------------------------------------+
   virtual int GetEntrySignal() = 0;
   
   //+------------------------------------------------------------------+
   //| Returns the Stop Loss distance in PRICE units (not points).      |
   //| Example: Returns 0.0050 (for EURUSD) or 15.5 (for DAX).          |
   //+------------------------------------------------------------------+
   virtual double GetStopLossDistance() = 0;
   
   //+------------------------------------------------------------------+
   //| Returns the Take Profit distance in PRICE units.                 |
   //| Usually calculated based on the SL distance (Risk:Reward).       |
   //+------------------------------------------------------------------+
   virtual double GetTakeProfitDistance(double slDistance) = 0;
};