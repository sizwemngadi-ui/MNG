#property copyright "Modified by Cursor Cloud Agent"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string InpAllowedSymbols       = "Crash 300 Index,Crash 500 Index";
input double InpLotSize              = 0.20;
input uint   InpTakeProfitPoints     = 100;
input int    InpMaxTradeSeconds      = 30;   // <=0 disables time-close
input int    InpSlippagePoints       = 50;
input ulong  InpMagicNumber          = 3476;
input bool   InpAllowOnlyOnePosition = false;

CTrade trade;
datetime g_lastM1BarTime = 0;

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
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber
         && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         return true;
      }
   }
   return false;
}

void CloseExpiredPositions()
{
   if(InpMaxTradeSeconds <= 0)
      return;

   datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(now - openTime) >= (long)InpMaxTradeSeconds)
      {
         if(!trade.PositionClose(ticket))
         {
            Print("Failed to close expired position #", ticket,
                  " retcode=", trade.ResultRetcode(),
                  " ", trade.ResultRetcodeDescription());
         }
      }
   }
}

bool IsNewM1Bar(datetime &barOpenTime)
{
   datetime times[];
   if(CopyTime(_Symbol, PERIOD_M1, 0, 1, times) != 1)
      return false;

   barOpenTime = times[0];
   return (barOpenTime > g_lastM1BarTime);
}

void OpenSellOnNewM1Bar()
{
   datetime barOpenTime = 0;
   if(!IsNewM1Bar(barOpenTime))
      return;

   g_lastM1BarTime = barOpenTime;

   if(InpAllowOnlyOnePosition && HasOpenSellForThisEA())
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(bid <= 0.0 || point <= 0.0)
      return;

   double tp = bid - ((double)InpTakeProfitPoints * point);
   tp = NormalizeDouble(tp, digits);

   if(!trade.Sell(InpLotSize, _Symbol, 0.0, 0.0, tp, "Sell each M1 candle"))
   {
      Print("Sell order failed. Retcode=", trade.ResultRetcode(),
            " ", trade.ResultRetcodeDescription());
   }
}

int OnInit()
{
   if(!SymbolAllowed())
   {
      Print("EA disabled for symbol ", _Symbol, ". Allowed list: ", InpAllowedSymbols);
      return INIT_FAILED;
   }

   if(_Period != PERIOD_M1)
      Print("Warning: chart timeframe is ", EnumToString(_Period), ". Entry logic still uses M1 candles.");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)InpSlippagePoints);

   datetime times[];
   if(CopyTime(_Symbol, PERIOD_M1, 0, 1, times) == 1)
      g_lastM1BarTime = times[0];
   else
      g_lastM1BarTime = 0;

   Print("CrashSellEveryCandle_Modified initialized on ", _Symbol, " (M1 entry logic).");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   CloseExpiredPositions();
   OpenSellOnNewM1Bar();
}
