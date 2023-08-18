#property description "HA candles with RSI"
//--- indicator settings
#property indicator_separate_window
#property indicator_minimum -50
#property indicator_maximum 50
#property indicator_level1 -20
#property indicator_level2 0
#property indicator_level3 20
#property indicator_buffers 11
#property indicator_plots   6

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrDarkGreen, clrFireBrick
#property indicator_label1    "HAO;HAH;HAL;HAC"

#property indicator_type2     DRAW_LINE
#property indicator_color2    clrGold
#property indicator_label2    "RSI"

#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  1
#property indicator_label3  "Bullish Divergence"

#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  1
#property indicator_label4  "Bearish Divergence"

#property indicator_type5     DRAW_LINE
#property indicator_color5    clrLime
#property indicator_width5  2
#property indicator_label5    "Bullish Divergence Line"

#property indicator_type6     DRAW_LINE
#property indicator_color6    clrRed
#property indicator_width6  2
#property indicator_label6    "Bearish Divergence Line"

//--- input parameters
input int harsi_length=14; // HA candles RSI period
input int harsi_smoothing_length = 7;  // HA candles smoothing period
input ENUM_APPLIED_PRICE rsi_source = PRICE_MEDIAN;  // RSI line source
input int rsi_length=7; // RSI line period
input bool rsi_smoothing=true;  // RSI line smoothing
input int ncandles_rsi_peak = 1;  // Number of candles to form a peak (to calculate RSI divergence)
input double rsi_divergence_min_slope = 0;  // Min slope of the RSI divergence
input double equal_peaks_margin_points = 0;  // Equal peaks points
input int max_backward_candles_for_divergence = 40;  // Number of backward candles to find peaks (to calculate RSI divergence)
input int max_backward_peaks_for_divergence = 3; // Maximum number of consecutive peaks that can form a divergence
input bool only_head_and_shoulder_divergence = false; // Show head & shoulder divergences only
input bool enable_alert = false;  // Enable alert

#define RSI_DIVERGENCE_MIN_HEAD_HEIGHT 5
#define PI 3.14159265
//--- indicator buffers
double HAO[], HAH[], HAL[], HAC[], HAClr[]; // heiken ashi candles
double RSI[];  // RSI line
double BullishDivergence[], BearishDivergence[];
double BullishDivergenceLine[], BearishDivergenceLine[];
double RSIPeak[]; // 0 none, 1 top, 2 bottom
int rsi_line_handle, rsi_o_handle, rsi_h_handle, rsi_l_handle, rsi_c_handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, HAO, INDICATOR_DATA);
   SetIndexBuffer(1, HAH, INDICATOR_DATA);
   SetIndexBuffer(2, HAL, INDICATOR_DATA);
   SetIndexBuffer(3, HAC, INDICATOR_DATA);
   SetIndexBuffer(4, HAClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, RSI, INDICATOR_DATA);
   SetIndexBuffer(6, BullishDivergence,INDICATOR_DATA);
   SetIndexBuffer(7, BearishDivergence,INDICATOR_DATA);
   SetIndexBuffer(8, BullishDivergenceLine,INDICATOR_DATA);
   SetIndexBuffer(9, BearishDivergenceLine,INDICATOR_DATA);
   SetIndexBuffer(10, RSIPeak, INDICATOR_CALCULATIONS);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
//--- sets first bar from what index will be drawn
   //PlotIndexSetInteger(0,PLOT_DRAW_BEGIN, MathMax(harsi_length, rsi_length));
   rsi_line_handle = iRSI(_Symbol, _Period, rsi_length, rsi_source);
   rsi_o_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_OPEN);
   rsi_h_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_HIGH);
   rsi_l_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_LOW);
   rsi_c_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_CLOSE);
   

   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(2, PLOT_ARROW, 225);

   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(3, PLOT_ARROW, 226);
   
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  }

void OnDeinit(const int reason){
   IndicatorRelease(rsi_line_handle);
   IndicatorRelease(rsi_o_handle);
   IndicatorRelease(rsi_h_handle);
   IndicatorRelease(rsi_l_handle);
   IndicatorRelease(rsi_c_handle);
}
//+------------------------------------------------------------------+
//| Relative Strength Index                                          |
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
   int start;
   if(prev_calculated==0){
      HAL[0] = -50;
      HAH[0] = -50;
      HAO[0] = -50;
      HAC[0] = -50;
      RSI[0] = 0;
      BullishDivergence[0] = EMPTY_VALUE;
      BearishDivergence[0] = EMPTY_VALUE;
      RSIPeak[0] = 0;
      start = 1;
   }else{
      start=prev_calculated-1;
   }

   for(int i=start; i<rates_total && !IsStopped(); i++){
      if(i<harsi_length){
         HAL[i] = -50;
         HAH[i] = -50;
         HAO[i] = -50;
         HAC[i] = -50;
         RSI[i] = 0;
         continue;
      }
      double rsio[1], rsih[1], rsil[1], rsic[1];
      CopyBuffer(rsi_o_handle, 0, rates_total-i-1, 1, rsio);
      CopyBuffer(rsi_h_handle, 0, rates_total-i-1, 1, rsih);
      CopyBuffer(rsi_l_handle, 0, rates_total-i-1, 1, rsil);
      CopyBuffer(rsi_c_handle, 0, rates_total-i-1, 1, rsic);
      rsio[0] -= 50;
      rsih[0] -= 50;
      rsil[0] -= 50;
      rsic[0] -= 50;
      double ha_open = (harsi_smoothing_length*HAO[i-1]+HAC[i-1])/(harsi_smoothing_length+1);
      double ha_close = (rsio[0]+rsih[0]+rsil[0]+rsic[0])/4;
      double ha_high = MathMax(MathMax(rsih[0],rsil[0]), MathMax(ha_open,ha_close));
      double ha_low = MathMin(MathMin(rsih[0],rsil[0]), MathMin(ha_open,ha_close));
      HAL[i] = ha_low;
      HAH[i] = ha_high;
      HAO[i] = ha_open;
      HAC[i] = ha_close;
      HAO[i] = NormalizeDouble(HAO[i], _Digits);
      HAC[i] = NormalizeDouble(HAC[i], _Digits);
      HAH[i] = NormalizeDouble(HAH[i], _Digits);
      HAL[i] = NormalizeDouble(HAL[i], _Digits);
      HAClr[i] = HAO[i]<HAC[i]? 0.0 : 1.0; // set candle color
      
      double rsival[1];
      CopyBuffer(rsi_line_handle, 0, rates_total-i-1, 1, rsival);
      rsival[0] -= 50;
      if(rsi_smoothing) rsival[0] = (rsival[0]+RSI[i-1])/2;
      RSI[i] = NormalizeDouble(rsival[0], 1);
      
      BullishDivergence[i] = EMPTY_VALUE;
      BearishDivergence[i] = EMPTY_VALUE;
      BullishDivergenceLine[i] = EMPTY_VALUE;
      BearishDivergenceLine[i] = EMPTY_VALUE;
      RSIPeak[i] = 0;
      int jpeak = i-1-ncandles_rsi_peak;
      bool istop = true;
      bool isbottom = true;
      for(int j=-ncandles_rsi_peak;j<=ncandles_rsi_peak;j++){
         if(j==0) continue;
         istop = istop && (RSI[jpeak]>=RSI[jpeak+j]);
         isbottom = isbottom && (RSI[jpeak]<=RSI[jpeak+j]);
      }
      if(istop) RSIPeak[jpeak] = 1;
      if(isbottom) RSIPeak[jpeak] = 2;
      if(istop && isbottom) RSIPeak[jpeak] = 0;
      
      if(RSIPeak[jpeak]>0 && jpeak>max_backward_candles_for_divergence){
         int npeaks_found = 0;
         for(int j=jpeak-1;j>=jpeak-max_backward_candles_for_divergence;j--){
            if(npeaks_found>=max_backward_peaks_for_divergence) break;
            if(RSIPeak[j]==1 && RSIPeak[jpeak]==1){ // check regular bearish divergence
               if((RSI[j]>=RSI[jpeak]-equal_peaks_margin_points*0.1) && (high[j]<=high[jpeak]+equal_peaks_margin_points*_Point)){
                  bool divergence_confirmed = false;
                  if(only_head_and_shoulder_divergence){
                     for(int m=j+1;m<jpeak;m++){
                        if(RSIPeak[m]==1 && RSI[m]>(m-j)*(RSI[jpeak]-RSI[j])/(jpeak-j)+RSI[j]+RSI_DIVERGENCE_MIN_HEAD_HEIGHT){
                           divergence_confirmed = true;
                           break;
                        }
                     }
                  }else{
                     divergence_confirmed = true;
                  }
                  if(divergence_confirmed && rsi_divergence_min_slope>0){
                     if(MathAbs(calc_slope(RSI[j],j,RSI[jpeak],jpeak))<rsi_divergence_min_slope) divergence_confirmed = false;
                  }
                  if(divergence_confirmed){
                     BearishDivergence[i-1] = RSI[jpeak];
                     for(int k=j;k<=jpeak;k++) BearishDivergenceLine[k] = RSI[j] + (k-j)*(RSI[jpeak]-RSI[j])/(jpeak-j);
                  }     
               }
               npeaks_found++;               
            }else if(RSIPeak[j]==2 && RSIPeak[jpeak]==2){ // check regular bullish divergence
               if((RSI[j]<=RSI[jpeak]+equal_peaks_margin_points*0.1) && (low[j]>=low[jpeak]-equal_peaks_margin_points*_Point)){
                  bool divergence_confirmed = false;
                  if(only_head_and_shoulder_divergence){
                     for(int m=j+1;m<jpeak;m++){
                        if(RSIPeak[m]==2 && RSI[m]<(m-j)*(RSI[jpeak]-RSI[j])/(jpeak-j)+RSI[j]-RSI_DIVERGENCE_MIN_HEAD_HEIGHT){
                           divergence_confirmed = true;
                           break;
                        }
                     }
                  }else{
                     divergence_confirmed = true;
                  }
                  if(divergence_confirmed && rsi_divergence_min_slope>0){
                     if(MathAbs(calc_slope(RSI[j],j,RSI[jpeak],jpeak))<rsi_divergence_min_slope) divergence_confirmed = false;
                  }
                  if(divergence_confirmed){
                     BullishDivergence[i-1] = RSI[jpeak];
                     for(int k=j;k<=jpeak;k++) BullishDivergenceLine[k] = RSI[j] + (k-j)*(RSI[jpeak]-RSI[j])/(jpeak-j);
                  }     
               }
               npeaks_found++;
            }
         }
      }
      
      if(HAClr[i-1]!=HAClr[i-2] && i==rates_total-2 && enable_alert) Alert(_Symbol + ": HARSI color changed.");
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+


double calc_slope(double p1, double i1, double p2, double i2){
   double m = (p1-p2)/(i1-i2);
   double rad = atan(m);
   double deg = 90*MathAbs(rad)/(PI/2);
   return deg;   
}