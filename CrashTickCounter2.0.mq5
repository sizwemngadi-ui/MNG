#property copyright "Cursor"
#property version   "2.01"
#property strict
#property indicator_chart_window
#property indicator_plots 0

input ENUM_BASE_CORNER LabelCorner = CORNER_LEFT_UPPER;
input int LabelXDistance = 10;
input int LabelYDistance = 20;
input color LabelColor = clrLime;
input int LabelFontSize = 12;
input string LabelFont = "Consolas";
input int DropThresholdPoints = 100;

string g_label_name = "CrashTickCounter2_0Label";
long g_total_ticks = 0;
long g_current_bar_ticks = 0;
long g_ticks_since_last_drop = 0;
long g_drop_events = 0;
datetime g_current_bar_open_time = 0;
datetime g_last_drop_time = 0;
double g_last_drop_points = 0.0;
double g_previous_bid = 0.0;
bool g_initialized = false;
bool g_has_previous_tick = false;
const ENUM_TIMEFRAMES COUNTER_TIMEFRAME = PERIOD_M1;

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
   const string last_drop_time_text =
      (g_last_drop_time > 0) ? TimeToString(g_last_drop_time, TIME_DATE | TIME_SECONDS) : "N/A";
   const string text =
      "CrashTickCounter2.0\n"
      + "Symbol: " + _Symbol + "\n"
      + "Timeframe: " + TimeframeToString(COUNTER_TIMEFRAME) + "\n"
      + "Ticks since last drop: " + (string)g_ticks_since_last_drop + "\n"
      + "Drop threshold (points): " + (string)DropThresholdPoints + "\n"
      + "Drop events: " + (string)g_drop_events + "\n"
      + "Last drop size (points): " + DoubleToString(g_last_drop_points, 1) + "\n"
      + "Last drop time: " + last_drop_time_text + "\n"
      + "Total ticks seen: " + (string)g_total_ticks + "\n"
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
   MqlTick tick;
   EnsureLabel();
   IndicatorSetString(INDICATOR_SHORTNAME, "CrashTickCounter2.0");

   g_current_bar_open_time = iTime(_Symbol, COUNTER_TIMEFRAME, 0);
   g_total_ticks = 0;
   g_current_bar_ticks = 0;
   g_ticks_since_last_drop = 0;
   g_drop_events = 0;
   g_last_drop_time = 0;
   g_last_drop_points = 0.0;
   g_previous_bid = 0.0;
   g_has_previous_tick = false;

   if(SymbolInfoTick(_Symbol, tick))
   {
      g_previous_bid = tick.bid;
      g_has_previous_tick = true;
   }

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
   MqlTick tick;
   datetime current_bar_open_time = iTime(_Symbol, COUNTER_TIMEFRAME, 0);

   if(!SymbolInfoTick(_Symbol, tick))
      return rates_total;

   if(!g_initialized)
   {
      g_current_bar_open_time = current_bar_open_time;
      g_initialized = true;
      g_previous_bid = tick.bid;
      g_has_previous_tick = true;
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

   if(g_has_previous_tick)
   {
      const double down_move_points = (g_previous_bid - tick.bid) / _Point;
      if(down_move_points >= DropThresholdPoints)
      {
         g_ticks_since_last_drop = 0;
         g_drop_events++;
         g_last_drop_points = down_move_points;
         g_last_drop_time = tick.time;
      }
      else
      {
         g_ticks_since_last_drop++;
      }
   }

   g_previous_bid = tick.bid;
   g_has_previous_tick = true;
   g_total_ticks++;
   UpdateDisplay();
   return rates_total;
}
