//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers   5
#property indicator_plots     2

#property indicator_label1 "ZoneUpperEdge"
#property indicator_color1 clrBlue, clrDeepSkyBlue, clrAqua
#property indicator_type1  DRAW_COLOR_LINE
#property indicator_width1 2

#property indicator_label2 "ZoneLowerEdge"
#property indicator_color2 clrBlue, clrDeepSkyBlue, clrAqua
#property indicator_type2  DRAW_COLOR_LINE
#property indicator_width2 2

input int zone_start_hour = 7;
input int zone_start_minute = 0;
input int zone_duration_minute = 60;
input int zone_terminate_hour = 20;
input int zone_terminate_minute = 0;

//--- indicator buffers
double ExtUpperEdge[];
double ExtUpperEdgeColor[];
double ExtLowerEdge[];
double ExtLowerEdgeColor[];
double ExtZoneType[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   SetIndexBuffer(0, ExtUpperEdge, INDICATOR_DATA);
   SetIndexBuffer(1, ExtUpperEdgeColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtLowerEdge, INDICATOR_DATA);
   SetIndexBuffer(3, ExtLowerEdgeColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, ExtZoneType, INDICATOR_CALCULATIONS);
//---
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "timezone_channel_indicator");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 1000000.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   int istart;
   if(prev_calculated==0){
      ExtUpperEdge[0] = 0;
      ExtLowerEdge[0] = 1000000;
      ExtUpperEdgeColor[0] = 0;
      ExtLowerEdgeColor[0] = 0;
      ExtZoneType[0] = 0;
      istart = 1;
   }else{
      istart = prev_calculated-1;
   }
   for(int i=istart; i<rates_total; i++){
      MqlDateTime stime, ttime;
      datetime datetime_start, datetime_end, datetime_terminate;
      TimeToStruct(time[i], stime);
      TimeToStruct(time[i], ttime);
      stime.hour = zone_start_hour;
      stime.min = zone_start_minute;
      stime.sec = 0;
      ttime.hour = zone_terminate_hour;
      ttime.min = zone_terminate_minute;
      ttime.sec = 0;
      datetime_start = StructToTime(stime);
      datetime_end = datetime_start + zone_duration_minute*60;
      datetime_terminate = StructToTime(ttime);
      ExtUpperEdge[i] = ExtUpperEdge[i-1];
      ExtLowerEdge[i] = ExtLowerEdge[i-1];
      if(time[i]>=datetime_start && time[i]<datetime_end){
         ExtZoneType[i] = 1;
         ExtUpperEdgeColor[i] = 0;
         ExtLowerEdgeColor[i] = 0;
         if(high[i]>ExtUpperEdge[i-1]) ExtUpperEdge[i] = high[i];
         if(low[i]<ExtLowerEdge[i-1]) ExtLowerEdge[i] = low[i];
      }else if(time[i]>=datetime_end && time[i]<=(datetime_end+datetime_terminate)/2){
         ExtZoneType[i] = 2;
         ExtUpperEdgeColor[i] = 1;
         ExtLowerEdgeColor[i] = 1;
      }else if(time[i]>(datetime_end+datetime_terminate)/2 && time[i]<datetime_terminate){
         ExtZoneType[i] = 3;
         ExtUpperEdgeColor[i] = 2;
         ExtLowerEdgeColor[i] = 2;
      }else{
         ExtZoneType[i] = 0;
         ExtUpperEdge[i] = 0;
         ExtLowerEdge[i] = 1000000;
      }
   }

   return (rates_total);
}

//+------------------------------------------------------------------+
