//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers   10
#property indicator_plots     5

#property indicator_label1 "ZoneUpperEdge"
#property indicator_color1 clrBlue, clrDeepSkyBlue, clrAqua
#property indicator_type1  DRAW_COLOR_LINE
#property indicator_width1 2

#property indicator_label2 "ZoneLowerEdge"
#property indicator_color2 clrBlue, clrDeepSkyBlue, clrAqua
#property indicator_type2  DRAW_COLOR_LINE
#property indicator_width2 2

#property indicator_label3 "InPosition"
#property indicator_color3 clrNONE, clrNONE
#property indicator_type3  DRAW_COLOR_LINE
#property indicator_width3 2

#property indicator_type4 DRAW_NONE
#property indicator_label4    "WinRate%"

#property indicator_type5 DRAW_NONE
#property indicator_label5    "ProfitPoints"

input int zone_start_hour = 3;
input int zone_start_minute = 0;
input int zone_duration_minute = 60;
input int zone_terminate_hour = 21;
input int zone_terminate_minute = 0;
input double no_new_trade_timerange_ratio = 0.5;
input bool backtesting = false;
input int n_days_backtest = 30;

//--- indicator buffers
double ExtUpperEdge[];
double ExtUpperEdgeColor[];
double ExtLowerEdge[];
double ExtLowerEdgeColor[];
double ExtInPositionLine[];
double ExtInPositionLineColor[];
double ExtInPosition[]; // 0 no position, 1 buy position, 2 sell position
double ExtWinRate[];
double ExtProfitPoints[];
double ExtZoneType[];

int InPositionChangedIndex[];

#define MID_PRICE (ExtLowerEdge[i]+ExtUpperEdge[i])/2

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   SetIndexBuffer(0, ExtUpperEdge, INDICATOR_DATA);
   SetIndexBuffer(1, ExtUpperEdgeColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtLowerEdge, INDICATOR_DATA);
   SetIndexBuffer(3, ExtLowerEdgeColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, ExtInPositionLine, INDICATOR_DATA);
   SetIndexBuffer(5, ExtInPositionLineColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, ExtWinRate, INDICATOR_DATA);
   SetIndexBuffer(7, ExtProfitPoints, INDICATOR_DATA);
   SetIndexBuffer(8, ExtInPosition, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, ExtZoneType, INDICATOR_CALCULATIONS);

//---
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "timezone_channel_indicator");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 1000000.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   
   ArrayFree(InPositionChangedIndex);
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
      ExtWinRate[0] = 0;
      ExtZoneType[0] = 0;
      ExtInPosition[0] = 0;
      ExtInPositionLine[0] = 0;
      ExtInPositionLineColor[0] = 0;
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
      ExtInPosition[i] = ExtInPosition[i-1];
      if(ExtInPosition[i]==1 && low[i]<ExtLowerEdge[i]) ExtInPosition[i] = 0;
      if(ExtInPosition[i]==2 && high[i]>ExtUpperEdge[i]) ExtInPosition[i] = 0;
      if(time[i]>=datetime_start && time[i]<datetime_end){
         ExtZoneType[i] = 1;
         ExtUpperEdgeColor[i] = 0;
         ExtLowerEdgeColor[i] = 0;
         if(high[i]>ExtUpperEdge[i-1]) ExtUpperEdge[i] = high[i];
         if(low[i]<ExtLowerEdge[i-1]) ExtLowerEdge[i] = low[i];
      }else if(time[i]>=datetime_end && time[i]<=datetime_end+(datetime_terminate-datetime_end)*no_new_trade_timerange_ratio){
         ExtZoneType[i] = 2;
         ExtUpperEdgeColor[i] = 1;
         ExtLowerEdgeColor[i] = 1;
         if(close[i]>ExtUpperEdge[i] && open[i]<ExtUpperEdge[i]) ExtInPosition[i] = 1;
         else if(close[i]<ExtLowerEdge[i] && open[i]>ExtLowerEdge[i]) ExtInPosition[i] = 2;
      }else if(time[i]>datetime_end+(datetime_terminate-datetime_end)*no_new_trade_timerange_ratio && time[i]<datetime_terminate){
         ExtZoneType[i] = 3;
         ExtUpperEdgeColor[i] = 2;
         ExtLowerEdgeColor[i] = 2;
      }else{
         ExtZoneType[i] = 0;
         ExtUpperEdge[i] = 0;
         ExtLowerEdge[i] = 1000000;
         ExtInPosition[i] = 0;
      }
      if(ExtInPosition[i]>0){
         ExtInPositionLine[i] = MID_PRICE;
         ExtInPositionLineColor[i] = ExtInPosition[i]-1;
      }

      
      // update winrate and profit points
      if(backtesting){
         
         if(ExtInPosition[i] != ExtInPosition[i-1]){
            int n = ArraySize(InPositionChangedIndex);
            ArrayResize(InPositionChangedIndex, n+1);
            InPositionChangedIndex[n] = i;
         }
      
         MqlDateTime st;
         datetime st_ = time[i];
         for(int d=1;d<=n_days_backtest;d++){         
            st_ -= 24*60*60;
            MqlDateTime temp;
            TimeToStruct(st_ , temp);
            if(temp.day_of_week==0) st_ -= 2*24*60*60;  // compensating for the weekends
         }
         TimeToStruct(st_, st);
         st.hour = 0;
         st.min = 0;
         st.sec = 0;
         datetime start_time = StructToTime(st);
         
         int npos = ArraySize(InPositionChangedIndex);
         int ntotal = 0;
         double nwins = 0;
         double prof = 0;
         for(int j=npos-1;j>1;j--){
            if(time[InPositionChangedIndex[j]]>=start_time) continue;
            j++;
            for(int k=j;k<npos;k++){
               int icandle_start = InPositionChangedIndex[k];
               int icandle_end;
               if(k==npos-1) icandle_end = i;
               else icandle_end = InPositionChangedIndex[k+1];
               MqlDateTime tstart, tend;
               TimeToStruct(time[icandle_start], tstart);
               TimeToStruct(time[icandle_end], tend);
               if(tstart.day != tend.day) continue;
               double plow = ExtLowerEdge[icandle_start];
               double phigh = ExtUpperEdge[icandle_start];
               if(ExtInPosition[icandle_start]==1){
                  ntotal++;
                  if(low[icandle_end]<plow){
                     prof += -(close[icandle_start]-plow);
                  }else{
                     prof += open[icandle_end] - close[icandle_start];
                     nwins++;
                  }
               }
               if(ExtInPosition[icandle_start]==2){
                  ntotal++;
                  if(high[icandle_end]>phigh){
                     prof += -(phigh-close[icandle_start]);
                  }else{
                     prof += close[icandle_start] - open[icandle_end];
                     nwins++;
                  }
               }
            }
            break;
         }
         if(ntotal!=0) ExtWinRate[i] = NormalizeDouble(100*nwins/ntotal, 2);
         ExtProfitPoints[i] = prof/_Point;
      }
   }
   return (rates_total);
}

//+------------------------------------------------------------------+
