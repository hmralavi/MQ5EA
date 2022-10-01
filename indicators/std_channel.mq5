#property description "Volatility STD Channel"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue
#property indicator_label1  "STD-HIGH"

#property indicator_type2   DRAW_LINE
#property indicator_color2  DodgerBlue
#property indicator_label2  "STD-LOW"
//--- input parameters
input int InpStdPeriod=100;  // STD period
input double InpStdChannelDeviation=2; // STD channel deviation
//--- indicator buffers
double sumbuffer[], stdbuffer[], stdhigh[], stdlow[];
#define HCALC(i) ((close[i]+open[i])/2+InpStdChannelDeviation*stdbuffer[i])
#define LCALC(i) ((close[i]+open[i])/2-InpStdChannelDeviation*stdbuffer[i])
#define DIFF(i)  (high[i]-low[i])
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, stdhigh, INDICATOR_DATA);
   SetIndexBuffer(1, stdlow, INDICATOR_DATA);
   SetIndexBuffer(2, sumbuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, stdbuffer, INDICATOR_CALCULATIONS);
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpStdPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpStdPeriod);
  }
//+------------------------------------------------------------------+
//| Average True Range                                               |
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
   
   if(rates_total<=InpStdPeriod) return(0);
   int start;
   if(prev_calculated==0){
      sumbuffer[0]=DIFF(0);
      stdbuffer[0]=0;
      stdhigh[0]=HCALC(0);
      stdlow[0]=LCALC(0);
      for(int i=1; i<rates_total && !IsStopped(); i++){
         sumbuffer[i] = sumbuffer[i-1] + DIFF(i);
         //if(i>=InpStdPeriod) sumbuffer[i]-=DIFF(i-InpStdPeriod);
         stdbuffer[i] = calculate_std(i, high, low);
         stdhigh[i]=HCALC(i);
         stdlow[i]=LCALC(i);         
      }
      start=InpStdPeriod+1;
   }else{
      start=prev_calculated-1;
   }
//--- the main loop of calculations
   for(int i=start; i<rates_total && !IsStopped(); i++){
      sumbuffer[i] = sumbuffer[i-1] + DIFF(i);
      if(i>=InpStdPeriod) sumbuffer[i]-=DIFF(i-InpStdPeriod);
      stdbuffer[i] = calculate_std(i, high, low);
      stdhigh[i]=HCALC(i);
      stdlow[i]=LCALC(i);        
   }
//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+

double calculate_std(int icandle, const double &high[], const double &low[]){
   int start = MathMax(0,icandle-InpStdPeriod+1);
   double std=0;
   double mean=sumbuffer[icandle]/InpStdPeriod;
   for(int i=start;i<=icandle;i++){
      std += (DIFF(i)-mean)*(DIFF(i)-mean);
   }
   std/=InpStdPeriod;
   std = MathSqrt(std);
   return std;
}