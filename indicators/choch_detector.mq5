//--- indicator settings
#property indicator_chart_window
#property indicator_buffers   8
#property indicator_plots     1
#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrLightGray, clrGray, clrLightGreen, clrLimeGreen, clrCoral, clrCrimson  // neutral trend; neutral trend peak; bullish trend; peak in bullish trend; bearish trend; peak in bearish trend
#property indicator_label1    "Open;High;Low;Close"

input int n_candles_peak = 6;

//--- indicator buffers
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];
double ExtColorBuffer[];
double ExtTrendbuffer[]; // 0 neutral, 1 bullish, 2 bearish
double ExtPeakBuffer[]; // 0 neutral, 1 top, 2 bottom
double ExtPeakBrokenBuffer[];
int PeakIndex[];
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
   SetIndexBuffer(5,ExtTrendbuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,ExtPeakBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,ExtPeakBrokenBuffer,INDICATOR_CALCULATIONS); 
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
   if(prev_calculated==0){
      ExtLBuffer[0]=low[0];
      ExtHBuffer[0]=high[0];
      ExtOBuffer[0]=open[0];
      ExtCBuffer[0]=close[0];
      ExtColorBuffer[0]=0;
      ExtTrendbuffer[0]=0;
      ExtPeakBuffer[0]=0;
      ExtPeakBrokenBuffer[0]=0;
   }
   //--- detect peaks
   for(int i=MathMax(prev_calculated-n_candles_peak-1,1); i<rates_total-n_candles_peak-1 && !IsStopped(); i++){
      ExtPeakBuffer[i] = 0;      
      if(i>=n_candles_peak){
         bool top = true;
         bool bottom = true;
         for(int j=i-n_candles_peak;j<=i+n_candles_peak;j++){
            if(i==j) continue;
            top = top && high[i]>high[j];
            bottom = bottom && low[i]<low[j];
         }
         if(top) ExtPeakBuffer[i] = 1;
         if(bottom) ExtPeakBuffer[i] = 2;
         ExtPeakBrokenBuffer[i] = 0;
         if(top || bottom){
            int npeaks = ArraySize(PeakIndex);
            ArrayResize(PeakIndex, npeaks+1);
            PeakIndex[npeaks] = i;    
            ExtColorBuffer[i] = ExtTrendbuffer[i]*2 + 1;        
         }
      }
   }
   
   //--- detect chock
   for(int i=MathMax(prev_calculated-2,1); i<rates_total && !IsStopped(); i++){

      ExtLBuffer[i]=low[i];
      ExtHBuffer[i]=high[i];
      ExtOBuffer[i]=open[i];
      ExtCBuffer[i]=close[i];      
      if(i==rates_total-1) continue;
      if(ExtTrendbuffer[i]>0) continue;
      ExtTrendbuffer[i] = ExtTrendbuffer[i-1];   
      int npeaks = ArraySize(PeakIndex);     
      for(int j=npeaks-1;j>=0;j--){
         int pindex = PeakIndex[j];
         if(i<pindex) continue;
         if(ExtPeakBuffer[pindex]==1 && ExtPeakBrokenBuffer[pindex]==0 && close[i]>high[pindex]){
            ExtTrendbuffer[i] = 1;
            ExtPeakBrokenBuffer[pindex] = 1;          
         }else if(ExtPeakBuffer[pindex]==2 && ExtPeakBrokenBuffer[pindex]==0 && close[i]<low[pindex]){
            ExtTrendbuffer[i] = 2;
            ExtPeakBrokenBuffer[pindex] = 1;  
         }
      }
      ExtColorBuffer[i] = 2*ExtTrendbuffer[i];
      if(ExtPeakBuffer[i]>0) ExtColorBuffer[i]++; 
   }
   //---
   return(rates_total);
}
//+------------------------------------------------------------------+
