//--- indicator settings
#property indicator_chart_window
#property indicator_buffers   15
#property indicator_plots     8

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrLightGray, clrGray, C'64,64,0', C'86,214,86', C'78,14,14', C'255,79,79'  // neutral trend; neutral trend peak; bullish trend; peak in bullish trend; bearish trend; peak in bearish trend
#property indicator_label1    "Open;High;Low;Close"

#property indicator_type2 DRAW_NONE
#property indicator_label2    "BOS number"

#property indicator_type3 DRAW_NONE
#property indicator_label3    "Broken candle price"

#property indicator_type4 DRAW_NONE
#property indicator_label4    "Broken candle shift"

#property indicator_type5 DRAW_NONE
#property indicator_label5    "WinRate%"

#property indicator_type6 DRAW_NONE
#property indicator_label6    "ProfitPoints"

#property indicator_type7 DRAW_NONE
#property indicator_label7    "LossPoints"

#property indicator_type8 DRAW_NONE
#property indicator_label8    "NetProfitPoints"

input int n_candles_peak = 6;
input double peak_slope_min = 0;
input int static_dynamic_support_resistant = 0;  // set 0 for both static and trendline, set 1 for static only, set 2 for trendline only
input bool backtesting = false;
input int n_trend_change_win_rate = 10;

//--- indicator buffers
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];
double ExtColorBuffer[];
double ExtWinRateBuffer[];
double ExtProfitPointsbuffer[];
double ExtLossPointsBuffer[];
double ExtNetProfitPointsBuffer[];
double ExtTrendbuffer[]; // 0 neutral, 1 bullish, 2 bearish
double ExtPeakBuffer[]; // 0 neutral, 1 top, 2 bottom
double ExtPeakBrokenBuffer[];
double ExtBosBuffer[];
double ExtBosPriceBuffer[];
double ExtBosShiftBuffer[];

int PeakIndex[];
int TrendChangedIndex[];

#define ISGREEN(j) close[j]>open[j]
#define ISRED(j) close[j]<open[j]
#define SPREAD(j) MathAbs(high[j]-low[j])
#define BODYRATIO(j) MathAbs(close[j]-open[j])/MathAbs(high[j]-low[j])
#define PI 3.14159265
#define MAX_STORED_PEAKS 100

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtOBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtHBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtLBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtCBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,ExtColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5,ExtBosBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,ExtBosPriceBuffer,INDICATOR_DATA);
   SetIndexBuffer(7,ExtBosShiftBuffer,INDICATOR_DATA);
   SetIndexBuffer(8,ExtWinRateBuffer,INDICATOR_DATA); 
   SetIndexBuffer(9,ExtProfitPointsbuffer,INDICATOR_DATA);
   SetIndexBuffer(10,ExtLossPointsBuffer,INDICATOR_DATA);
   SetIndexBuffer(11,ExtNetProfitPointsBuffer,INDICATOR_DATA);
   SetIndexBuffer(12,ExtTrendbuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(13,ExtPeakBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(14,ExtPeakBrokenBuffer,INDICATOR_CALCULATIONS); 
   
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   IndicatorSetString(INDICATOR_SHORTNAME,"choch_detector");
//--- sets drawing line empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   
   //ChartSetInteger(0, CHART_MODE, CHART_LINE);
   //color clr = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   //ChartSetInteger(0, CHART_COLOR_CHART_LINE, clr);
   ArrayFree(PeakIndex);
   ArrayFree(TrendChangedIndex);
  }
//+------------------------------------------------------------------+
//| Heiken Ashi                                                      |
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
                const int &spread[]){
   int start;                
   if(prev_calculated==0){
      ExtLBuffer[0]=low[0];
      ExtHBuffer[0]=high[0];
      ExtOBuffer[0]=open[0];
      ExtCBuffer[0]=close[0];
      ExtColorBuffer[0]=0;
      ExtTrendbuffer[0]=0;
      ExtPeakBuffer[0]=0;
      ExtPeakBrokenBuffer[0]=0;
      ExtBosBuffer[0]=0;
      start = 1;
   }else{
      start = prev_calculated - 2;
   } 

   for(int i=start; i<rates_total && !IsStopped(); i++){
      // update candle price
      ExtLBuffer[i]=low[i];
      ExtHBuffer[i]=high[i];
      ExtOBuffer[i]=open[i];
      ExtCBuffer[i]=close[i];     
      if(i==rates_total-1) continue;  // dont further analyze the unclosed candle
      if(ExtTrendbuffer[i]>0) continue;
      
      //--------------------------------
      //-------detect peaks and nodes-------------
      //--------------------------------
      ExtPeakBuffer[i] = 0; 
      ExtPeakBrokenBuffer[i] = 0;
      
      // detect peaks
      if(i>=2*n_candles_peak){
         int jpeak = i-n_candles_peak;
         bool top = true;
         bool bottom = true;
         for(int j=-n_candles_peak;j<=n_candles_peak;j++){
            if(j==0) continue;
            top = top && high[jpeak]>=high[jpeak+j] && calc_slope(high[jpeak], 0, high[jpeak+j], j)>peak_slope_min*j/n_candles_peak;
            bottom = bottom && low[jpeak]<=low[jpeak+j] && calc_slope(low[jpeak], 0, low[jpeak+j], j)>peak_slope_min*j/n_candles_peak;
         }
         assign_as_peak(jpeak, top, bottom);        
      }
      
      // detect nodes
      if(i>10){
         int jnode=i-1;
         bool top = false;
         bool bottom = false;                  
         
         if(ISGREEN(jnode+1) && ISRED(jnode) && ISGREEN(jnode-1) && close[jnode+1]>close[jnode-1] && low[jnode]>open[jnode-1] && high[jnode]<close[jnode+1] && MathAbs(high[jnode-2]-low[jnode-1])/SPREAD(jnode-1)<0.7){
            bottom = true;
         }
         if(ISRED(jnode+1) && ISGREEN(jnode) && ISRED(jnode-1) && close[jnode+1]<close[jnode-1] && high[jnode]<open[jnode-1] && low[jnode]>close[jnode+1] && MathAbs(low[jnode-2]-high[jnode-1])/SPREAD(jnode-1)<0.7){
            top = true;
         }
         assign_as_peak(jnode, top, bottom);         
      }
      
      //--------------------------------
      //-------detect choch and bos-----
      //--------------------------------
      ExtTrendbuffer[i] = ExtTrendbuffer[i-1];
      ExtBosBuffer[i] = ExtBosBuffer[i-1];
      ExtBosPriceBuffer[i] = 0;
      ExtBosShiftBuffer[i] = 0;
      int npeaks = ArraySize(PeakIndex);    
      for(int j=0;j<npeaks;j++){
         int pindex = PeakIndex[j];   
         if(ExtPeakBrokenBuffer[pindex]==1) continue;     
         if(ExtPeakBuffer[pindex]==1){
            bool trend_line_broken = false;
            bool trend_line_broken1 = false;
            bool trend_line_broken2 = false;
            trend_line_broken1 = close[i]>high[pindex];
            if(static_dynamic_support_resistant==0 || static_dynamic_support_resistant==2){
               int pindex_before = -1;
               for(int k=j-1;k>=0;k--){
                  if(ExtPeakBuffer[PeakIndex[k]]==1 && high[PeakIndex[k]]>high[pindex]){
                     bool trend_change = false;
                     for(int m=PeakIndex[k]+1;m<i;m++){
                        trend_change = trend_change || ExtTrendbuffer[m]!=ExtTrendbuffer[pindex];
                        if(trend_change) break;
                     }
                     if(trend_change) break;
                     pindex_before = PeakIndex[k];
                     break;
                  }
               }
               if(pindex_before>0) trend_line_broken2 = close[i]>calc_trend_line_price(high[pindex_before], pindex_before, high[pindex], pindex, i);
            }
            if(static_dynamic_support_resistant==0) trend_line_broken = trend_line_broken1 || trend_line_broken2;
            if(static_dynamic_support_resistant==1) trend_line_broken = trend_line_broken1;
            if(static_dynamic_support_resistant==2) trend_line_broken = trend_line_broken2;
            if(trend_line_broken){
               ExtTrendbuffer[i] = 1;
               ExtPeakBrokenBuffer[pindex] = 1;
               if(ExtTrendbuffer[i]!= ExtTrendbuffer[i-1]) ExtBosBuffer[i] = 1;
               else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
               ExtBosPriceBuffer[i] = high[pindex];
               ExtBosShiftBuffer[i] = i-pindex;
               //assign_as_peak(i, false, true); // this means: cosider the breaking candle as a peak. but lets keep it disable as it generates bad results.
            }
            
         }else if(ExtPeakBuffer[pindex]==2){
            bool trend_line_broken = false;
            bool trend_line_broken1 = false;
            bool trend_line_broken2 = false;            
            trend_line_broken1 = close[i]<low[pindex];
            if(static_dynamic_support_resistant==0 || static_dynamic_support_resistant==2){
               int pindex_before = -1;
               for(int k=j-1;k>=0;k--){
                  if(ExtPeakBuffer[PeakIndex[k]]==2 && low[PeakIndex[k]]<low[pindex]){
                     bool trend_change = false;
                     for(int m=PeakIndex[k]+1;m<i;m++){
                        trend_change = trend_change || ExtTrendbuffer[m]!=ExtTrendbuffer[pindex];
                        if(trend_change) break;
                     }
                     if(trend_change) break;
                     pindex_before = PeakIndex[k];
                     break;
                  }
               }               
               if(pindex_before>0) trend_line_broken2 = close[i]<calc_trend_line_price(low[pindex_before], pindex_before, low[pindex], pindex, i);
            }
            if(static_dynamic_support_resistant==0) trend_line_broken = trend_line_broken1 || trend_line_broken2;
            if(static_dynamic_support_resistant==1) trend_line_broken = trend_line_broken1;
            if(static_dynamic_support_resistant==2) trend_line_broken = trend_line_broken2;
            if(trend_line_broken){
               ExtTrendbuffer[i] = 2;
               ExtPeakBrokenBuffer[pindex] = 1;
               if(ExtTrendbuffer[i]!= ExtTrendbuffer[i-1]) ExtBosBuffer[i] = 1;
               else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
               ExtBosPriceBuffer[i] = low[pindex];
               ExtBosShiftBuffer[i] = i-pindex;
               //assign_as_peak(i, true, false);  // this means: cosider the breaking candle as a peak. but lets keep it disable as it generates bad results.
            }
         }
      }
      ExtColorBuffer[i] = 2*ExtTrendbuffer[i];
            
      //--- update win rate
      if(backtesting){
         int ntrendchanged = ArraySize(TrendChangedIndex);
         if(ExtTrendbuffer[i] != ExtTrendbuffer[i-1]){
            ArrayResize(TrendChangedIndex, ntrendchanged+1);
            TrendChangedIndex[ntrendchanged] = i;    
            ntrendchanged++;   
         }
         double wins = 0;
         double profit_points = 0;
         double loss_points = 0;
         double net_profit_points = 0;
         for(int k=ntrendchanged-n_trend_change_win_rate-1;k<ntrendchanged-1;k++){
            if(k<0) continue;
            int startindex = TrendChangedIndex[k];
            int endindex = TrendChangedIndex[k+1];
            if(ExtTrendbuffer[startindex]==1){
               if(close[endindex]>close[startindex]){
                  wins++;
                  profit_points += (close[endindex] - close[startindex]) / _Point;
               }else{
                  loss_points += (close[endindex] - close[startindex]) / _Point;
               }
            }
            if(ExtTrendbuffer[startindex]==2){
               if(close[endindex]<close[startindex]){
                  wins++;
                  profit_points += (close[startindex] - close[endindex]) / _Point;
               }else{
                  loss_points += (close[startindex] - close[endindex]) / _Point;
               }
            }

         }
         double winrate = NormalizeDouble(100*wins/n_trend_change_win_rate, 1);
         ExtWinRateBuffer[i] = winrate;
         ExtProfitPointsbuffer[i] = profit_points;
         ExtLossPointsBuffer[i] = loss_points;
         ExtNetProfitPointsBuffer[i] = profit_points+loss_points;
      }      
   }
   //---
   return(rates_total);
}
//+------------------------------------------------------------------+


double calc_trend_line_price(double p1, double i1, double p2, double i2, double i3){
   double p3 = p1+(p1-p2)*(i3-i1)/(i1-i2);
   return p3;
}

double calc_slope(double p1, double i1, double p2, double i2){
   double m = (p1-p2)/(i1-i2)/_Point;
   double rad = atan(m);
   double deg = 90*MathAbs(rad)/(PI/2);
   return deg;   
}

void assign_as_peak(int jpeak, bool istop, bool isbottom){
   if(ExtPeakBuffer[jpeak]>0) return;
   if(istop) ExtPeakBuffer[jpeak] = 1;
   if(isbottom) ExtPeakBuffer[jpeak] = 2;
   if(istop || isbottom){
      int npeaks = ArraySize(PeakIndex);
      if(npeaks+1>MAX_STORED_PEAKS){
         ArrayRemove(PeakIndex, 0, 1);
         npeaks = ArraySize(PeakIndex);
      }
      ArrayResize(PeakIndex, npeaks+1);
      PeakIndex[npeaks] = jpeak;    
      ExtColorBuffer[jpeak] = ExtTrendbuffer[jpeak]*2 + 1;        
   }
}