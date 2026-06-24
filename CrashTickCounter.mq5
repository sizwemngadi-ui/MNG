#property copyright "Cursor"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

input ENUM_BASE_CORNER LabelCorner = CORNER_LEFT_UPPER;
input int LabelXDistance = 10;
input int LabelYDistance = 20;
input color LabelColor = clrLime;
input int LabelFontSize = 12;
input string LabelFont = "Consolas";

string g_label_name = "CrashTickCounterLabel";
long g_total_ticks = 0;
long g_current_bar_ticks = 0;
datetime g_current_bar_open_time = 0;
bool g_initialized = false;

string TimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   string raw = EnumToString(timeframe);
   if(StringFind(raw, "PERIOD_") == 0)
      return StringSubstr(raw, 7);
   return raw;
}

void EnsureLabel()
{
   if(ObjectFind(0, g_label_name) == -1)
      ObjectCreate(0, g_label_name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, g_label_name, OBJPROP_CORNER, LabelCorner);
   ObjectSetInteger(0, g_label_name, OBJPROP_XDISTANCE, LabelXDistance);
   ObjectSetInteger(0, g_label_name, OBJPROP_YDISTANCE, LabelYDistance);
   ObjectSetInteger(0, g_label_name, OBJPROP_COLOR, LabelColor);
   ObjectSetInteger(0, g_label_name, OBJPROP_FONTSIZE, LabelFontSize);
   ObjectSetString(0, g_label_name, OBJPROP_FONT, LabelFont);
}

void UpdateDisplay()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   const int spread_points = (int)MathRound((tick.ask - tick.bid) / _Point);
   const string text =
      "Tick Counter\n"
      + "Symbol: " + _Symbol + "\n"
      + "Timeframe: " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + "\n"
      + "Total ticks: " + (string)g_total_ticks + "\n"
      + "Current candle ticks: " + (string)g_current_bar_ticks + "\n"
      + "Bid: " + DoubleToString(tick.bid, _Digits) + "\n"
      + "Ask: " + DoubleToString(tick.ask, _Digits) + "\n"
      + "Spread (points): " + (string)spread_points + "\n"
      + "Server time: " + TimeToString(TimeCurrent(), TIME_SECONDS);

   EnsureLabel();
   ObjectSetString(0, g_label_name, OBJPROP_TEXT, text);
}

int OnInit()
{
   EnsureLabel();
   g_current_bar_open_time = iTime(_Symbol, _Period, 0);
   g_total_ticks = 0;
   g_current_bar_ticks = 0;
   g_initialized = false;
   UpdateDisplay();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, g_label_name);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   datetime current_bar_open_time = iTime(_Symbol, _Period, 0);

   if(!g_initialized)
   {
      g_current_bar_open_time = current_bar_open_time;
      g_initialized = true;
      UpdateDisplay();
      return rates_total;
   }

   if(current_bar_open_time != g_current_bar_open_time)
   {
      g_current_bar_open_time = current_bar_open_time;
      g_current_bar_ticks = 1;
   }
   else
   {
      g_current_bar_ticks++;
   }

   g_total_ticks++;
   UpdateDisplay();
   return rates_total;
}
