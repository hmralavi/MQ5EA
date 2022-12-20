//--- indicator settings
#property indicator_chart_window
#property indicator_buffers   10
#property indicator_plots     3
#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrLightGray, clrGray, clrLightGreen, clrLimeGreen, clrCoral, clrCrimson  // neutral trend; neutral trend peak; bullish trend; peak in bullish trend; bearish trend; peak in bearish trend
#property indicator_label1    "Open;High;Low;Close"

#property indicator_type2 DRAW_NONE
#property indicator_label2    "WinRate%"

#property indicator_type3 DRAW_NONE
#property indicator_label3    "ProfitPoints"

input int n_candles_peak = 6;
input int static_dynamic_support_resistant = 0;  // set 1 for static, 2 for dynamic support resistant, set 0 for both
input int n_trend_change_win_rate = 10;

//--- indicator buffers
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];
double ExtColorBuffer[];
double ExtWinRateBuffer[];
double ExtProfitPointsbuffer[];
double ExtTrendbuffer[]; // 0 neutral, 1 bullish, 2 bearish
double ExtPeakBuffer[]; // 0 neutral, 1 top, 2 bottom
double ExtPeakBrokenBuffer[];

int PeakIndex[];
int TrendChangedIndex[];
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
   SetIndexBuffer(5,ExtWinRateBuffer,INDICATOR_DATA); 
   SetIndexBuffer(6,ExtProfitPointsbuffer,INDICATOR_DATA); 
   SetIndexBuffer(7,ExtTrendbuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,ExtPeakBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,ExtPeakBrokenBuffer,INDICATOR_CALCULATIONS); 
   
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   IndicatorSetString(INDICATOR_SHORTNAME,"choch_detector");
//--- sets drawing line empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   
   ChartSetInteger(0, CHART_MODE, CHART_LINE);
   color clr = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clr);
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
      //--detect peak
      ExtPeakBuffer[i] = 0; 
      ExtPeakBrokenBuffer[i] = 0;
      if(i>=2*n_candles_peak){
         int jpeak = i-n_candles_peak;
         bool top = true;
         bool bottom = true;
         for(int j=jpeak-n_candles_peak;j<=jpeak+n_candles_peak;j++){
            if(j==jpeak) continue;
            top = top && high[jpeak]>high[j];
            bottom = bottom && low[jpeak]<low[j];
         }
         if(top) ExtPeakBuffer[jpeak] = 1;
         if(bottom) ExtPeakBuffer[jpeak] = 2;
         if(top || bottom){
            int npeaks = ArraySize(PeakIndex);
            ArrayResize(PeakIndex, npeaks+1);
            PeakIndex[npeaks] = jpeak;    
            ExtColorBuffer[jpeak] = ExtTrendbuffer[jpeak]*2 + 1;        
         }         
      }
      //--detect choch
      ExtTrendbuffer[i] = ExtTrendbuffer[i-1];   
      int npeaks = ArraySize(PeakIndex);     
      for(int j=0;j<npeaks;j++){
         int pindex = PeakIndex[j];        
         if(ExtPeakBuffer[pindex]==1 && ExtPeakBrokenBuffer[pindex]==0){
            bool trend_line_broken = false;
            bool trend_line_broken1 = false;
            bool trend_line_broken2 = false;
            trend_line_broken1 = close[i]>high[pindex];            
            int pindex_before = -1;
            for(int k=j-1;k>=MathMax(0,j-6);k--){
               if(ExtPeakBuffer[PeakIndex[k]]==1 && high[PeakIndex[k]]>high[pindex]){
                  pindex_before = PeakIndex[k];
                  break;
               }
            }
            if(pindex_before>0) trend_line_broken2 = close[i]>calc_trend_line_price(high[pindex_before], pindex_before, high[pindex], pindex, i);
            if(static_dynamic_support_resistant==0) trend_line_broken = trend_line_broken1 || trend_line_broken2;
            if(static_dynamic_support_resistant==1) trend_line_broken = trend_line_broken1;
            if(static_dynamic_support_resistant==2) trend_line_broken = trend_line_broken2;
            if(trend_line_broken){
               ExtTrendbuffer[i] = 1;
               ExtPeakBrokenBuffer[pindex] = 1;          
            }
            
         }else if(ExtPeakBuffer[pindex]==2 && ExtPeakBrokenBuffer[pindex]==0){
            bool trend_line_broken = false;
            bool trend_line_broken1 = false;
            bool trend_line_broken2 = false;            
            trend_line_broken1 = close[i]<low[pindex];
            int pindex_before = -1;
            for(int k=j-1;k>=MathMax(0,j-6);k--){
               if(ExtPeakBuffer[PeakIndex[k]]==2 && low[PeakIndex[k]]<low[pindex]){
                  pindex_before = PeakIndex[k];
                  break;
               }
            }               
            if(pindex_before>0) trend_line_broken2 = close[i]<calc_trend_line_price(low[pindex_before], pindex_before, low[pindex], pindex, i);           
            if(static_dynamic_support_resistant==0) trend_line_broken = trend_line_broken1 || trend_line_broken2;
            if(static_dynamic_support_resistant==1) trend_line_broken = trend_line_broken1;
            if(static_dynamic_support_resistant==2) trend_line_broken = trend_line_broken2;
            if(trend_line_broken){
               ExtTrendbuffer[i] = 2;
               ExtPeakBrokenBuffer[pindex] = 1;          
            }
         }
      }
      ExtColorBuffer[i] = 2*ExtTrendbuffer[i];
            
      //--- update win rate
      int ntrendchanged = ArraySize(TrendChangedIndex);
      if(ExtTrendbuffer[i] != ExtTrendbuffer[i-1]){
         ArrayResize(TrendChangedIndex, ntrendchanged+1);
         TrendChangedIndex[ntrendchanged] = i;    
         ntrendchanged++;   
      }
      double wins = 0;
      double profit_points = 0;
      for(int k=ntrendchanged-n_trend_change_win_rate-1;k<ntrendchanged-1;k++){
         if(k<0) continue;
         int startindex = TrendChangedIndex[k];
         int endindex = TrendChangedIndex[k+1];
         if(close[endindex]>close[startindex] && ExtTrendbuffer[startindex]==1) wins++;
         if(close[endindex]<close[startindex] && ExtTrendbuffer[startindex]==2) wins++;
         if(ExtTrendbuffer[startindex]==1) profit_points += (close[endindex] - close[startindex]) / _Point;
         if(ExtTrendbuffer[startindex]==2) profit_points += (close[startindex] - close[endindex]) / _Point;
      }
      double winrate = NormalizeDouble(100*wins/n_trend_change_win_rate, 1);
      ExtWinRateBuffer[i] = winrate;
      ExtProfitPointsbuffer[i] = profit_points;
   }
   //---
   return(rates_total);
}
//+------------------------------------------------------------------+


double calc_trend_line_price(double p1, double i1, double p2, double i2, double i3){
   double p3 = p1+(p1-p2)*(i3-i1)/(i1-i2);
   return p3;
}