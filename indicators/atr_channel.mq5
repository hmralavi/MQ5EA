#property description "Average True Range Channel"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue
#property indicator_label1  "ATR-HIGH"

#property indicator_type2   DRAW_LINE
#property indicator_color2  DodgerBlue
#property indicator_label2  "ATR-LOW"
//--- input parameters
input int InpAtrPeriod=100;  // ATR period
input double InpAtrChannelDeviation=2; // ATR channel deviation
//--- indicator buffers
double ExtATRBuffer[], ExtTRBuffer[], atrhigh[], atrlow[];
int ExtPeriodATR;
#define HCALC(i) ((close[i]+open[i])/2+InpAtrChannelDeviation*ExtATRBuffer[i])
#define LCALC(i) ((close[i]+open[i])/2-InpAtrChannelDeviation*ExtATRBuffer[i])
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input value
   if(InpAtrPeriod<=0)
     {
      ExtPeriodATR=14;
      PrintFormat("Incorrect input parameter InpAtrPeriod = %d. Indicator will use value %d for calculations.",InpAtrPeriod,ExtPeriodATR);
     }
   else
      ExtPeriodATR=InpAtrPeriod;
//--- indicator buffers mapping
   SetIndexBuffer(0, atrhigh, INDICATOR_DATA);
   SetIndexBuffer(1, atrlow, INDICATOR_DATA);
   SetIndexBuffer(2, ExtATRBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, ExtTRBuffer, INDICATOR_CALCULATIONS);
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpAtrPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpAtrPeriod);
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
                const int &spread[])
  {
   if(rates_total<=ExtPeriodATR)
      return(0);

   int i,start;
//--- preliminary calculations
   if(prev_calculated==0)
     {
      ExtTRBuffer[0]=0.0;
      ExtATRBuffer[0]=0.0;
      atrhigh[0]=HCALC(0);
      atrlow[0]=LCALC(0);
      //--- filling out the array of True Range values for each period
      for(i=1; i<rates_total && !IsStopped(); i++)
         ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      //--- first AtrPeriod values of the indicator are not calculated
      double firstValue=0.0;
      for(i=1; i<=ExtPeriodATR; i++)
        {
         ExtATRBuffer[i]=0.0;
         atrhigh[i]=HCALC(i);
         atrlow[i]=LCALC(i);
         firstValue+=ExtTRBuffer[i];
        }
      //--- calculating the first value of the indicator
      firstValue/=ExtPeriodATR;
      ExtATRBuffer[ExtPeriodATR]=firstValue;
      atrhigh[ExtPeriodATR]=HCALC(ExtPeriodATR);
      atrlow[ExtPeriodATR]=LCALC(ExtPeriodATR);
      start=ExtPeriodATR+1;
     }
   else
      start=prev_calculated-1;
//--- the main loop of calculations
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      ExtATRBuffer[i]=ExtATRBuffer[i-1]+(ExtTRBuffer[i]-ExtTRBuffer[i-ExtPeriodATR])/ExtPeriodATR;
      atrhigh[i]=HCALC(i);
      atrlow[i]=LCALC(i);      
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
