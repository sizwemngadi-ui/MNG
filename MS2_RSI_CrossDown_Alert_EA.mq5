#property strict
#property version   "1.00"
#property description "RSI cross-down push alert EA for MT5"

input string          InpSymbol            = "";            // Empty = current chart symbol
input ENUM_TIMEFRAMES InpRSITimeframe      = PERIOD_M5;     // RSI calculation timeframe
input int             InpRSIPeriod         = 14;            // RSI period
input ENUM_APPLIED_PRICE InpAppliedPrice   = PRICE_CLOSE;   // RSI applied price
input double          InpTriggerRSI        = 30.0;          // Alert when RSI crosses down this level
input bool            InpEnablePushAlert   = true;          // Send push notification
input bool            InpEnablePopupAlert  = true;          // Show terminal popup alert

int      g_rsiHandle = INVALID_HANDLE;
string   g_symbol    = "";
datetime g_lastBarTime = 0;

string TimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "TF(" + IntegerToString((int)timeframe) + ")";
   }
}

bool IsCrossDown(const double previousValue, const double currentValue, const double trigger)
{
   return (previousValue > trigger && currentValue <= trigger);
}

void SendRsiAlert(const double previousRsi, const double currentRsi)
{
   string message = StringFormat(
      "RSI CROSS DOWN on %s [%s] | Trigger: %.2f | Prev RSI: %.2f | Current RSI: %.2f",
      g_symbol,
      TimeframeToString(InpRSITimeframe),
      InpTriggerRSI,
      previousRsi,
      currentRsi
   );

   Print(message);

   if(InpEnablePopupAlert)
      Alert(message);

   if(InpEnablePushAlert)
   {
      if(!SendNotification(message))
         Print("SendNotification failed. Error: ", GetLastError());
   }
}

int OnInit()
{
   g_symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
   if(!SymbolSelect(g_symbol, true))
   {
      Print("Failed to select symbol ", g_symbol, ". Error: ", GetLastError());
      return INIT_FAILED;
   }

   if(InpRSIPeriod < 1)
   {
      Print("Invalid RSI period. Please use a value >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpTriggerRSI < 0.0 || InpTriggerRSI > 100.0)
   {
      Print("Invalid trigger RSI. Please use a value between 0 and 100.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_rsiHandle = iRSI(g_symbol, InpRSITimeframe, InpRSIPeriod, InpAppliedPrice);
   if(g_rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to create RSI handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   Print("EA initialized on symbol ", g_symbol, " with timeframe ", TimeframeToString(InpRSITimeframe),
         ", RSI period ", InpRSIPeriod, ", trigger ", DoubleToString(InpTriggerRSI, 2));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_rsiHandle);
      g_rsiHandle = INVALID_HANDLE;
   }
}

void OnTick()
{
   if(g_rsiHandle == INVALID_HANDLE)
      return;

   datetime barTimes[1];
   if(CopyTime(g_symbol, InpRSITimeframe, 1, 1, barTimes) != 1)
      return;

   if(barTimes[0] == g_lastBarTime)
      return;

   g_lastBarTime = barTimes[0];

   double rsiValues[2];
   // shift 1: last closed bar, shift 2: previous closed bar
   if(CopyBuffer(g_rsiHandle, 0, 1, 2, rsiValues) != 2)
      return;

   const double currentRsi  = rsiValues[0];
   const double previousRsi = rsiValues[1];

   if(IsCrossDown(previousRsi, currentRsi, InpTriggerRSI))
      SendRsiAlert(previousRsi, currentRsi);
}
