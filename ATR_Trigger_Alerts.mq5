#property strict
#property version   "1.05"
#property description "Alerts on ATR trigger cross in both directions and shows timer while ATR stays below trigger."

input string            InpSymbol              = "Crash 300 Index";   // Symbol to monitor
input ENUM_TIMEFRAMES   InpTimeframe           = PERIOD_M5;           // Timeframe to monitor
input int               InpATRPeriod           = 14;                  // ATR period
input double            InpATRTriggerLevel     = 3.300;               // Trigger level
input bool              InpEnablePushNotify    = true;                // Send mobile push notification
input bool              InpEnablePopupAlert    = true;                // Show MT5 popup alert
input bool              InpTriggerOnCrossOnly  = true;                // Alert on trigger transitions only
input bool              InpDisplayAtrOnChart   = true;                // Show live ATR value on chart
input bool              InpDrawVerticalLine    = true;                // Draw vertical line when alert triggers
input color             InpLineColor           = clrRed;              // Vertical line color
input ENUM_LINE_STYLE   InpLineStyle           = STYLE_SOLID;         // Vertical line style
input int               InpLineWidth           = 1;                   // Vertical line width

enum AlertDirection
{
   ALERT_CROSS_DOWN = -1,
   ALERT_CROSS_UP   = 1
};

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

   bool crossedDown = (previousATR > InpATRTriggerLevel && currentATR <= InpATRTriggerLevel);
   bool crossedUp = (previousATR <= InpATRTriggerLevel && currentATR > InpATRTriggerLevel);

   bool triggerDown = false;
   bool triggerUp = false;

   if(InpTriggerOnCrossOnly)
   {
      triggerDown = crossedDown;
      triggerUp = crossedUp;
   }
   else
   {
      bool isBelowNow = (currentATR <= InpATRTriggerLevel);
      bool wasBelow = g_levelAlreadyBelow;

      triggerDown = (isBelowNow && !wasBelow);
      triggerUp = (!isBelowNow && wasBelow);
   }

   if(triggerDown)
      SendAtrAlert(symbolToUse, currentATR, currentBarTime, ALERT_CROSS_DOWN);

   if(triggerUp)
      SendAtrAlert(symbolToUse, currentATR, currentBarTime, ALERT_CROSS_UP);

   // Persist level state to detect next transition.
   g_levelAlreadyBelow = (currentATR <= InpATRTriggerLevel);
}

void SendAtrAlert(string symbolName, double atrValue, datetime triggerTime, AlertDirection direction)
{
   string directionText = (direction == ALERT_CROSS_DOWN ? "down through" : "up through");
   string message = StringFormat("%s ATR(%d) on %s crossed %s %.3f (current: %.3f)",
                                 symbolName, InpATRPeriod, EnumToString(InpTimeframe),
                                 directionText, InpATRTriggerLevel, atrValue);

   Print(message);

   if(InpEnablePopupAlert)
      Alert(message);

   if(InpEnablePushNotify)
   {
      if(!SendNotification(message))
         PrintFormat("SendNotification failed. Error: %d", GetLastError());
   }

   if(direction == ALERT_CROSS_DOWN)
   {
      g_timerActive = true;
      g_timerStartTime = TimeLocal();
      g_timerStartAtr = atrValue;
   }
   else
   {
      g_timerActive = false;
      g_timerStartTime = 0;
      g_timerStartAtr = 0.0;
   }

   if(InpDrawVerticalLine)
      DrawTriggerLine(triggerTime, atrValue, direction);

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

void DrawTriggerLine(datetime triggerTime, double atrValue, AlertDirection direction)
{
   string directionSuffix = (direction == ALERT_CROSS_DOWN ? "DownCross" : "UpCross");
   string objectName = StringFormat("ATR_%s_%I64d", directionSuffix, (long)triggerTime);
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
