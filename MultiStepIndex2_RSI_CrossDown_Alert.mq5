#property strict
#property version   "1.00"
#property description "RSI cross-down alert EA with push notifications."

input string             InpSymbol                 = "Multi Step index 2";
input ENUM_TIMEFRAMES    InpTimeframe              = PERIOD_M5;
input int                InpRsiPeriod              = 14;
input ENUM_APPLIED_PRICE InpRsiAppliedPrice        = PRICE_CLOSE;
input double             InpTriggerRsiValue        = 50.0;
input bool               InpEnablePushNotification = true;
input bool               InpEnablePopupAlert       = true;
input bool               InpEnableJournalPrint     = true;

int               g_rsiHandle      = INVALID_HANDLE;
datetime          g_lastAlertedBar = 0;
string            g_symbol         = "";
ENUM_TIMEFRAMES   g_timeframe;

void NotifyUser(const string message)
{
   if(InpEnableJournalPrint)
      Print(message);

   if(InpEnablePopupAlert)
      Alert(message);

   if(InpEnablePushNotification)
   {
      ResetLastError();
      if(!SendNotification(message))
         PrintFormat("SendNotification failed. Error=%d", GetLastError());
   }
}

bool ReadClosedBarRsi(double &olderClosedBarRsi, double &latestClosedBarRsi, datetime &latestClosedBarTime)
{
   double rsiValues[3];
   datetime times[3];
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(times, true);

   if(CopyBuffer(g_rsiHandle, 0, 0, 3, rsiValues) != 3)
   {
      Print("Failed to read RSI buffer.");
      return false;
   }

   if(CopyTime(g_symbol, g_timeframe, 0, 3, times) != 3)
   {
      Print("Failed to read candle time series.");
      return false;
   }

   latestClosedBarRsi = rsiValues[1];
   olderClosedBarRsi  = rsiValues[2];
   latestClosedBarTime = times[1];
   return true;
}

int OnInit()
{
   g_symbol = InpSymbol;
   StringTrimLeft(g_symbol);
   StringTrimRight(g_symbol);
   if(StringLen(g_symbol) == 0)
      g_symbol = _Symbol;

   g_timeframe = InpTimeframe;

   if(!SymbolSelect(g_symbol, true))
      PrintFormat("Warning: failed to select symbol '%s'.", g_symbol);

   g_rsiHandle = iRSI(g_symbol, g_timeframe, InpRsiPeriod, InpRsiAppliedPrice);
   if(g_rsiHandle == INVALID_HANDLE)
   {
      PrintFormat("Failed to create RSI handle for '%s' on %s. Error=%d",
                  g_symbol, EnumToString(g_timeframe), GetLastError());
      return INIT_FAILED;
   }

   PrintFormat("EA initialized: Symbol=%s, Timeframe=%s, RSI period=%d, Trigger=%.2f",
               g_symbol, EnumToString(g_timeframe), InpRsiPeriod, InpTriggerRsiValue);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_rsiHandle);
}

void OnTick()
{
   if(g_rsiHandle == INVALID_HANDLE)
      return;

   double olderClosedBarRsi = 0.0;
   double latestClosedBarRsi = 0.0;
   datetime latestClosedBarTime = 0;

   if(!ReadClosedBarRsi(olderClosedBarRsi, latestClosedBarRsi, latestClosedBarTime))
      return;

   if(latestClosedBarTime == g_lastAlertedBar)
      return;

   if(olderClosedBarRsi > InpTriggerRsiValue && latestClosedBarRsi <= InpTriggerRsiValue)
   {
      g_lastAlertedBar = latestClosedBarTime;
      string message = StringFormat("%s (%s): RSI crossed down %.2f [prev=%.2f, now=%.2f]",
                                    g_symbol,
                                    EnumToString(g_timeframe),
                                    InpTriggerRsiValue,
                                    olderClosedBarRsi,
                                    latestClosedBarRsi);
      NotifyUser(message);
   }
}
