#property strict
#property version   "1.00"
#property description "Alerts when ATR reaches a configured level on M5."

input string            InpSymbol              = "Crash 300 Index";   // Symbol to monitor
input ENUM_TIMEFRAMES   InpTimeframe           = PERIOD_M5;           // Timeframe to monitor
input int               InpATRPeriod           = 14;                  // ATR period
input double            InpATRTriggerLevel     = 3.300;               // Trigger level
input bool              InpEnablePushNotify    = true;                // Send mobile push notification
input bool              InpEnablePopupAlert    = true;                // Show MT5 popup alert
input bool              InpTriggerOnCrossOnly  = true;                // Alert only when crossing up

int      g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;
bool     g_levelAlreadyReached = false;

int OnInit()
{
   string symbolToUse = StringTrim(InpSymbol);
   if(symbolToUse == "")
      symbolToUse = _Symbol;

   if(!SymbolSelect(symbolToUse, true))
   {
      PrintFormat("Failed to select symbol '%s'.", symbolToUse);
      return(INIT_FAILED);
   }

   g_atrHandle = iATR(symbolToUse, InpTimeframe, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      PrintFormat("Failed to create ATR handle for %s on timeframe %d. Error: %d",
                  symbolToUse, InpTimeframe, GetLastError());
      return(INIT_FAILED);
   }

   // Prime state from latest ATR value to prevent false first alert.
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrValues) == 1)
      g_levelAlreadyReached = (atrValues[0] >= InpATRTriggerLevel);

   PrintFormat("ATR alert initialized for %s, TF=%d, period=%d, trigger=%.3f",
               symbolToUse, InpTimeframe, InpATRPeriod, InpATRTriggerLevel);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
}

void OnTick()
{
   string symbolToUse = StringTrim(InpSymbol);
   if(symbolToUse == "")
      symbolToUse = _Symbol;

   datetime currentBarTime = iTime(symbolToUse, InpTimeframe, 0);
   if(currentBarTime == 0)
      return;

   // Evaluate once per bar to avoid repeated alerts on every tick.
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 2, atrValues) < 1)
   {
      PrintFormat("CopyBuffer failed. Error: %d", GetLastError());
      return;
   }

   double currentATR = atrValues[0];
   double previousATR = (ArraySize(atrValues) > 1 ? atrValues[1] : currentATR);

   bool triggerNow = false;
   if(InpTriggerOnCrossOnly)
      triggerNow = (previousATR < InpATRTriggerLevel && currentATR >= InpATRTriggerLevel);
   else
      triggerNow = (currentATR >= InpATRTriggerLevel && !g_levelAlreadyReached);

   if(triggerNow)
      SendAtrAlert(symbolToUse, currentATR);

   // Reset state if ATR goes back below level; enables next cycle alert.
   g_levelAlreadyReached = (currentATR >= InpATRTriggerLevel);
}

void SendAtrAlert(string symbolName, double atrValue)
{
   string message = StringFormat("%s ATR( %d ) on M5 reached %.3f (current: %.3f)",
                                 symbolName, InpATRPeriod, InpATRTriggerLevel, atrValue);

   Print(message);

   if(InpEnablePopupAlert)
      Alert(message);

   if(InpEnablePushNotify)
   {
      if(!SendNotification(message))
         PrintFormat("SendNotification failed. Error: %d", GetLastError());
   }
}

string StringTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}
