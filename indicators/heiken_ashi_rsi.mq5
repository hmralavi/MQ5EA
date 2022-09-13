//+------------------------------------------------------------------+
//|                                                          RSI.mq5 |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2009-2017, MetaQuotes Software Corp."
#property link        "http://www.mql5.com"
#property description "Relative Strength Index"
//--- indicator settings
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30
#property indicator_level2 70
#property indicator_buffers 7
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue
//--- input parameters
input int InpPeriodRSI=14; // Period
//--- indicator buffers
double    ExtRSIBuffer[];
double    ExtPosBuffer[];
double    ExtNegBuffer[];
double    ExtOBuffer[];
double    ExtHBuffer[];
double    ExtLBuffer[];
double    ExtCBuffer[];
int       ExtPeriodRSI;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input
   if(InpPeriodRSI<1)
     {
      ExtPeriodRSI=14;
      PrintFormat("Incorrect value for input variable InpPeriodRSI = %d. Indicator will use value %d for calculations.",
                  InpPeriodRSI,ExtPeriodRSI);
     }
   else
      ExtPeriodRSI=InpPeriodRSI;
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtRSIBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtPosBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,ExtNegBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ExtOBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,ExtHBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,ExtLBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,ExtCBuffer,INDICATOR_CALCULATIONS);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,2);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtPeriodRSI);
//--- name for DataWindow and indicator subwindow label
   IndicatorSetString(INDICATOR_SHORTNAME,"RSI("+string(ExtPeriodRSI)+")");
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
      ExtLBuffer[0]=low[0];
      ExtHBuffer[0]=high[0];
      ExtOBuffer[0]=open[0];
      ExtCBuffer[0]=close[0];
      start=1;
   }else{
      start=prev_calculated-1;
   }

   for(int i=start; i<rates_total && !IsStopped(); i++){
      double ha_open = (ExtOBuffer[i-1]+ExtCBuffer[i-1])/2;
      double ha_close = (open[i]+high[i]+low[i]+close[i])/4;
      double ha_high = MathMax(high[i],MathMax(ha_open,ha_close));
      double ha_low = MathMin(low[i],MathMin(ha_open,ha_close));
      double ma;
      ExtLBuffer[i]=ha_low;
      ExtHBuffer[i]=ha_high;
      ExtOBuffer[i]=ha_open;
      ExtCBuffer[i]=ha_close;
     }

   if(rates_total<=ExtPeriodRSI)
      return(0);
      
   int pos=prev_calculated-1;
   if(pos<=ExtPeriodRSI)
     {
      double sum_pos=0.0;
      double sum_neg=0.0;
      //--- first RSIPeriod values of the indicator are not calculated
      ExtRSIBuffer[0]=0.0;
      ExtPosBuffer[0]=0.0;
      ExtNegBuffer[0]=0.0;
      for(int i=1; i<=ExtPeriodRSI; i++)
        {
         ExtRSIBuffer[i]=0.0;
         ExtPosBuffer[i]=0.0;
         ExtNegBuffer[i]=0.0;
         double diff=ExtCBuffer[i]-ExtCBuffer[i-1];
         sum_pos+=(diff>0?diff:0);
         sum_neg+=(diff<0?-diff:0);
        }
      //--- calculate first visible value
      ExtPosBuffer[ExtPeriodRSI]=sum_pos/ExtPeriodRSI;
      ExtNegBuffer[ExtPeriodRSI]=sum_neg/ExtPeriodRSI;
      if(ExtNegBuffer[ExtPeriodRSI]!=0.0)
         ExtRSIBuffer[ExtPeriodRSI]=100.0-(100.0/(1.0+ExtPosBuffer[ExtPeriodRSI]/ExtNegBuffer[ExtPeriodRSI]));
      else
        {
         if(ExtPosBuffer[ExtPeriodRSI]!=0.0)
            ExtRSIBuffer[ExtPeriodRSI]=100.0;
         else
            ExtRSIBuffer[ExtPeriodRSI]=50.0;
        }
      //--- prepare the position value for main calculation
      pos=ExtPeriodRSI+1;
     }
//--- the main loop of calculations
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      double diff=ExtCBuffer[i]-ExtCBuffer[i-1];
      ExtPosBuffer[i]=(ExtPosBuffer[i-1]*(ExtPeriodRSI-1)+(diff>0.0?diff:0.0))/ExtPeriodRSI;
      ExtNegBuffer[i]=(ExtNegBuffer[i-1]*(ExtPeriodRSI-1)+(diff<0.0?-diff:0.0))/ExtPeriodRSI;
      if(ExtNegBuffer[i]!=0.0)
         ExtRSIBuffer[i]=100.0-100.0/(1+ExtPosBuffer[i]/ExtNegBuffer[i]);
      else
        {
         if(ExtPosBuffer[i]!=0.0)
            ExtRSIBuffer[i]=100.0;
         else
            ExtRSIBuffer[i]=50.0;
        }
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
