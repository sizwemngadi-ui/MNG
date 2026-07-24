#property strict
#property description "RSI trigger EA for Crash 300/500/1000 with alerts, vertical lines, and timer."

input int                InpRSIPeriod       = 14;           // RSI period
input double             InpTriggerRSI      = 70.0;         // Trigger level (upward crossing)
input ENUM_APPLIED_PRICE InpAppliedPrice    = PRICE_CLOSE;  // RSI applied price
input color              InpLineColor       = clrOrangeRed; // Vertical line color
input ENUM_LINE_STYLE    InpLineStyle       = STYLE_DOT;    // Vertical line style
input int                InpLineWidth       = 1;            // Vertical line width
input bool               InpShowSymbolHint  = true;         // Print hint when symbol is not Crash 300/500/1000
input bool               InpUsePopupAlert   = true;         // Show MT5 popup alert
input bool               InpUseSoundAlert   = true;         // Play sound on trigger
input string             InpSoundFile       = "alert.wav";  // Sound file

int      g_rsiHandle            = INVALID_HANDLE;
double   g_previousRsi          = 0.0;
double   g_latestRsi            = EMPTY_VALUE;
datetime g_triggerStartTime     = 0;
bool     g_hasPreviousRsi       = false;
bool     g_timerRunning         = false;
bool     g_isCrashSymbol        = false;
ulong    g_triggerCounter       = 0;

bool IsCrashSymbol(const string symbol)
{
   string normalized = symbol;
   StringToUpper(normalized);

   if(StringFind(normalized, "CRASH 300") >= 0)
      return true;
   if(StringFind(normalized, "CRASH 500") >= 0)
      return true;
   if(StringFind(normalized, "CRASH 1000") >= 0)
      return true;

   return false;
}

string FormatElapsed(const int elapsedSeconds)
{
   int hours   = elapsedSeconds / 3600;
   int minutes = (elapsedSeconds % 3600) / 60;
   int seconds = elapsedSeconds % 60;

   return StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
}

void UpdateChartDisplay()
{
   string rsiText = "n/a";
   if(g_latestRsi != EMPTY_VALUE)
      rsiText = DoubleToString(g_latestRsi, 2);

   string timerText = "not started";
   if(g_timerRunning)
   {
      int elapsed = (int)(TimeLocal() - g_triggerStartTime);
      if(elapsed < 0)
         elapsed = 0;
      timerText = FormatElapsed(elapsed);
   }

   Comment(
      "Crash RSI Trigger EA\n",
      "Symbol: ", _Symbol, " | Timeframe: ", EnumToString((ENUM_TIMEFRAMES)_Period), "\n",
      "Current RSI(", IntegerToString(InpRSIPeriod), "): ", rsiText, "\n",
      "Up Trigger Level: ", DoubleToString(InpTriggerRSI, 2), "\n",
      "Timer Since Last Trigger: ", timerText, "\n",
      "Crash Symbol Match (300/500/1000): ", (g_isCrashSymbol ? "yes" : "no")
   );
}

void DrawTriggerLine(const datetime triggerTime)
{
   string lineName = StringFormat("RSI_TRIGGER_LINE_%I64d_%I64u", (long)triggerTime, g_triggerCounter);
   if(!ObjectCreate(0, lineName, OBJ_VLINE, 0, triggerTime, 0.0))
   {
      Print("Failed to create trigger line. Error: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpLineColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, InpLineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
}

void HandleTrigger(const double currentRsi)
{
   g_timerRunning     = true;
   g_triggerStartTime = TimeLocal();
   g_triggerCounter++;

   datetime triggerTime = TimeCurrent();
   DrawTriggerLine(triggerTime);

   string msg = StringFormat(
      "%s %s RSI(%d) crossed UP %.2f (current %.2f)",
      _Symbol,
      EnumToString((ENUM_TIMEFRAMES)_Period),
      InpRSIPeriod,
      InpTriggerRSI,
      currentRsi
   );

   Print(msg);
   if(InpUsePopupAlert)
      Alert(msg);
   if(InpUseSoundAlert)
      PlaySound(InpSoundFile);
}

int OnInit()
{
   if(InpRSIPeriod < 2)
   {
      Print("Invalid RSI period: ", InpRSIPeriod, ". It must be >= 2.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpTriggerRSI < 0.0 || InpTriggerRSI > 100.0)
   {
      Print("Invalid trigger RSI level: ", InpTriggerRSI, ". It must be between 0 and 100.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_isCrashSymbol = IsCrashSymbol(_Symbol);
   if(InpShowSymbolHint && !g_isCrashSymbol)
      Print("Hint: This EA is designed for Crash 300/500/1000, but is running on ", _Symbol, ".");

   g_rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, InpAppliedPrice);
   if(g_rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to create RSI handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   EventSetTimer(1);
   UpdateChartDisplay();

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_rsiHandle);
   Comment("");
}

void OnTick()
{
   if(g_rsiHandle == INVALID_HANDLE)
      return;

   double rsiValues[1];
   int copied = CopyBuffer(g_rsiHandle, 0, 0, 1, rsiValues);
   if(copied <= 0)
   {
      Print("Failed to read RSI data. Error: ", GetLastError());
      return;
   }

   double currentRsi = rsiValues[0];
   g_latestRsi = currentRsi;

   if(g_hasPreviousRsi && g_previousRsi < InpTriggerRSI && currentRsi >= InpTriggerRSI)
      HandleTrigger(currentRsi);

   g_previousRsi = currentRsi;
   g_hasPreviousRsi = true;

   UpdateChartDisplay();
}

void OnTimer()
{
   UpdateChartDisplay();
}
