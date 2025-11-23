//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                      Copyright 2025, Expert MQL5 |
//| Description: Calculates lots based on Price Distance (ATR friendly)|
//+------------------------------------------------------------------+
#property strict

class CRiskManager {
public:
   //+------------------------------------------------------------------+
   //| NEW: Accepts 'slDistancePrice' (e.g., 0.0050) instead of Points  |
   //+------------------------------------------------------------------+
   double GetLotSize(double riskPercent, double slDistancePrice, string symbol) {
      //--- Validate inputs
      if(slDistancePrice <= 0.0) return 0.0;
      
      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * (riskPercent / 100.0);
      
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize == 0 || tickValue == 0) return 0.0;
      
      //--- STEP 1: Calculate the monetary loss for 1.00 Lot
      // Formula: (Distance / TickSize) * TickValue
      // Example: (0.0020 / 0.00001) * $1 = 200 ticks * $1 = $200 loss per lot
      double lossPerLot = (slDistancePrice / tickSize) * tickValue;
      
      if(lossPerLot == 0) return 0.0;
      
      //--- STEP 2: Calculate required Lot Size
      // Example: Risk $100 / Loss $200 = 0.5 Lots
      double lotSize = riskMoney / lossPerLot;
      
      //--- STEP 3: Normalize to Broker Limits
      double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      // Round down to step
      lotSize = MathFloor(lotSize / step) * step;
      
      if(lotSize < minLot) lotSize = minLot; // Or return 0.0 to skip trade
      if(lotSize > maxLot) lotSize = maxLot;
      
      return lotSize;
   }
};