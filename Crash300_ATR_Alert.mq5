#property strict
#property version   "1.03"
#property description "Alerts on downward ATR cross and shows timer only while ATR is below trigger."

input string            InpSymbol              = "Crash 300 Index";   // Symbol to monitor
input ENUM_TIMEFRAMES   InpTimeframe           = PERIOD_M5;           // Timeframe to monitor
input int               InpATRPeriod           = 14;                  // ATR period
input double            InpATRTriggerLevel     = 3.300;               // Trigger level
input bool              InpEnablePushNotify    = true;                // Send mobile push notification
input bool              InpEnablePopupAlert    = true;                // Show MT5 popup alert
input bool              InpTriggerOnCrossOnly  = true;                // Alert only when crossing down
input bool              InpDisplayAtrOnChart   = true;                // Show live ATR value on chart
input bool              InpDrawVerticalLine    = true;                // Draw vertical line when alert triggers
input color             InpLineColor           = clrRed;              // Vertical line color
input ENUM_LINE_STYLE   InpLineStyle           = STYLE_SOLID;         // Vertical line style
input int               InpLineWidth           = 1;                   // Vertical line width

int      g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;
bool     g_levelAlreadyBelow = false;
bool     g_timerActive = false;
datetime g_timerStartTime = 0;
double   g_timerStartAtr = 0.0;

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
      g_levelAlreadyBelow = (atrValues[0] <= InpATRTriggerLevel);

   PrintFormat("ATR alert initialized for %s, TF=%d, period=%d, trigger=%.3f",
               symbolToUse, InpTimeframe, InpATRPeriod, InpATRTriggerLevel);

   // Refresh on-chart timer display every second, even on quiet ticks.
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   if(InpDisplayAtrOnChart)
      Comment("");
}

void OnTimer()
{
   if(!InpDisplayAtrOnChart || g_atrHandle == INVALID_HANDLE)
      return;

   string symbolToUse = StringTrim(InpSymbol);
   if(symbolToUse == "")
      symbolToUse = _Symbol;

   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrValues) < 1)
      return;

   UpdateAtrDisplay(symbolToUse, atrValues[0]);
}

void OnTick()
{
   string symbolToUse = StringTrim(InpSymbol);
   if(symbolToUse == "")
      symbolToUse = _Symbol;

   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 2, atrValues) < 1)
   {
      PrintFormat("CopyBuffer failed. Error: %d", GetLastError());
      return;
   }

   double currentATR = atrValues[0];
   double previousATR = (ArraySize(atrValues) > 1 ? atrValues[1] : currentATR);

   if(InpDisplayAtrOnChart)
      UpdateAtrDisplay(symbolToUse, currentATR);

   datetime currentBarTime = iTime(symbolToUse, InpTimeframe, 0);
   if(currentBarTime == 0)
      return;

   // Evaluate alerts once per bar to avoid repeated notifications.
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   bool triggerNow = false;
   bool crossedUp = (previousATR <= InpATRTriggerLevel && currentATR > InpATRTriggerLevel);
   if(InpTriggerOnCrossOnly)
      triggerNow = (previousATR > InpATRTriggerLevel && currentATR <= InpATRTriggerLevel);
   else
      triggerNow = (currentATR <= InpATRTriggerLevel && !g_levelAlreadyBelow);

   if(triggerNow)
      SendAtrAlert(symbolToUse, currentATR, currentBarTime);

   if(crossedUp && g_timerActive)
   {
      g_timerActive = false;
      g_timerStartTime = 0;
      g_timerStartAtr = 0.0;
      if(InpDisplayAtrOnChart)
         UpdateAtrDisplay(symbolToUse, currentATR);
   }

   // Reset state if ATR goes back above level; enables next cycle alert.
   g_levelAlreadyBelow = (currentATR <= InpATRTriggerLevel);
}

void SendAtrAlert(string symbolName, double atrValue, datetime triggerTime)
{
   string message = StringFormat("%s ATR( %d ) on M5 crossed down to %.3f (current: %.3f)",
                                 symbolName, InpATRPeriod, InpATRTriggerLevel, atrValue);

   Print(message);

   if(InpEnablePopupAlert)
      Alert(message);

   if(InpEnablePushNotify)
   {
      if(!SendNotification(message))
         PrintFormat("SendNotification failed. Error: %d", GetLastError());
   }

   g_timerActive = true;
   g_timerStartTime = TimeLocal();
   g_timerStartAtr = atrValue;

   if(InpDrawVerticalLine)
      DrawTriggerLine(triggerTime, atrValue);

   if(InpDisplayAtrOnChart)
      UpdateAtrDisplay(symbolName, atrValue);
}

void UpdateAtrDisplay(string symbolName, double atrValue)
{
   string levelState = (atrValue <= InpATRTriggerLevel ? "Below/At trigger" : "Above trigger");
   string chartText = StringFormat("ATR Monitor\nSymbol: %s\nTimeframe: %s\nATR(%d): %.3f\nTrigger: %.3f\nState: %s",
                                   symbolName, EnumToString(InpTimeframe), InpATRPeriod,
                                   atrValue, InpATRTriggerLevel, levelState);

   if(g_timerActive && g_timerStartTime > 0)
   {
      int elapsedSeconds = (int)MathMax(0, TimeLocal() - g_timerStartTime);
      chartText += StringFormat("\nTimer below trigger: %s\nTimer start ATR: %.3f",
                                FormatElapsedTime(elapsedSeconds), g_timerStartAtr);
   }

   Comment(chartText);
}

void DrawTriggerLine(datetime triggerTime, double atrValue)
{
   string objectName = StringFormat("ATR_DownCross_%I64d", (long)triggerTime);

   if(ObjectFind(0, objectName) >= 0)
      return;

   if(!ObjectCreate(0, objectName, OBJ_VLINE, 0, triggerTime, 0))
   {
      PrintFormat("Failed to create vertical line. Error: %d", GetLastError());
      return;
   }

   ObjectSetInteger(0, objectName, OBJPROP_COLOR, InpLineColor);
   ObjectSetInteger(0, objectName, OBJPROP_STYLE, InpLineStyle);
   ObjectSetInteger(0, objectName, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, true);
   ObjectSetString(0, objectName, OBJPROP_TEXT, StringFormat("ATR %.3f", atrValue));
}

string FormatElapsedTime(int totalSeconds)
{
   int hours = totalSeconds / 3600;
   int minutes = (totalSeconds % 3600) / 60;
   int seconds = totalSeconds % 60;
   return StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
}

string StringTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}
