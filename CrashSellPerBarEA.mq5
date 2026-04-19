#property copyright "Cursor Cloud Agent"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string InpAllowedSymbols        = "Crash 300 Index,Crash 500 Index";
input double InpLots                  = 0.20;
input uint   InpTakeProfitPoints      = 100;
input int    InpMaxTradeSeconds       = 30;
input int    InpSlippagePoints        = 50;
input ulong  InpMagicNumber           = 30050001;
input bool   InpAllowOnlyOnePosition  = false;

CTrade trade;
datetime g_lastProcessedBarTime = 0;

string Trim(const string value)
{
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
}

string Lower(const string value)
{
   string result = value;
   StringToLower(result);
   return result;
}

bool SymbolAllowed()
{
   string chunks[];
   int count = StringSplit(InpAllowedSymbols, ',', chunks);
   if(count <= 0)
      return true;

   string current = Lower(_Symbol);
   for(int i = 0; i < count; i++)
   {
      string allowed = Lower(Trim(chunks[i]));
      if(allowed == "")
         continue;

      // Support exact match and broker-specific suffix/prefix symbol names.
      if(current == allowed || StringFind(current, allowed) >= 0)
         return true;
   }

   return false;
}

bool HasOpenSellForThisEA()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      long type = PositionGetInteger(POSITION_TYPE);

      if(symbol == _Symbol && magic == (long)InpMagicNumber && type == POSITION_TYPE_SELL)
         return true;
   }

   return false;
}

void CloseExpiredPositions()
{
   if(InpMaxTradeSeconds <= 0)
      return;

   datetime now = TimeCurrent();
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      long type = PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      if(symbol != _Symbol || magic != (long)InpMagicNumber || type != POSITION_TYPE_SELL)
         continue;

      long ageSeconds = (long)(now - openTime);
      if(ageSeconds >= (long)InpMaxTradeSeconds)
         trade.PositionClose(ticket);
   }
}

bool IsNewBar(datetime &barOpenTime)
{
   datetime times[];
   int copied = CopyTime(_Symbol, PERIOD_M1, 0, 1, times);
   if(copied != 1)
      return false;

   barOpenTime = times[0];
   return (barOpenTime > g_lastProcessedBarTime);
}

void OpenSellOnNewBar()
{
   datetime barOpenTime = 0;
   if(!IsNewBar(barOpenTime))
      return;

   g_lastProcessedBarTime = barOpenTime;

   if(InpAllowOnlyOnePosition && HasOpenSellForThisEA())
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(bid <= 0.0 || point <= 0.0)
      return;

   double tp = bid - ((double)InpTakeProfitPoints * point);
   tp = NormalizeDouble(tp, digits);

   if(!trade.Sell(InpLots, _Symbol, 0.0, 0.0, tp, "Sell each new candle"))
      Print("Sell order failed. Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}

int OnInit()
{
   if(!SymbolAllowed())
   {
      Print("EA disabled on symbol ", _Symbol, ". Allowed: ", InpAllowedSymbols);
      return INIT_FAILED;
   }

   if(_Period != PERIOD_M1)
      Print("Warning: chart timeframe is ", EnumToString(_Period), ". EA logic still uses M1 candles.");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)InpSlippagePoints);

   datetime times[];
   if(CopyTime(_Symbol, PERIOD_M1, 0, 1, times) == 1)
      g_lastProcessedBarTime = times[0];
   else
      g_lastProcessedBarTime = 0;

   Print("CrashSellPerBarEA initialized on ", _Symbol, " timeframe M1.");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   CloseExpiredPositions();
   OpenSellOnNewBar();
}
