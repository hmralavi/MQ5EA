//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                  Heiken_Ashi.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <MovingAverages.mqh>
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers   7
#property indicator_plots     2
#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrDodgerBlue, clrRed
#property indicator_label1    "Heiken Ashi Open;Heiken Ashi High;Heiken Ashi Low;Heiken Ashi Close"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrBlue
#property indicator_label2    "MA"

input ENUM_MA_METHOD MAMethod = MODE_EMA;
input int MAPeriod=10;

//--- indicator buffers
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];
double ExtColorBuffer[];
double ExtMABuffer[];
double ExtMAColorBuffer[];
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
   SetIndexBuffer(5,ExtMABuffer,INDICATOR_DATA);
   SetIndexBuffer(6,ExtMAColorBuffer,INDICATOR_COLOR_INDEX);
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   IndicatorSetString(INDICATOR_SHORTNAME,"Heiken Ashi & MA");
//--- sets drawing line empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   ChartSetInteger(0, CHART_MODE, CHART_LINE);
   color clr = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clr);
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
                const int &spread[])
  {
   int start;
//--- preliminary calculations
   if(prev_calculated==0)
     {
      ExtLBuffer[0]=low[0];
      ExtHBuffer[0]=high[0];
      ExtOBuffer[0]=open[0];
      ExtCBuffer[0]=close[0];
      ExtMABuffer[0]=close[0];
      start=1;
     }
   else
      start=prev_calculated-1;

//--- the main loop of calculations
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      double ha_open = (ExtOBuffer[i-1]+ExtCBuffer[i-1])/2;
      double ha_close = (open[i]+high[i]+low[i]+close[i])/4;
      double ha_high = MathMax(high[i],MathMax(ha_open,ha_close));
      double ha_low = MathMin(low[i],MathMin(ha_open,ha_close));
      double ma;
      ExtLBuffer[i]=ha_low;
      ExtHBuffer[i]=ha_high;
      ExtOBuffer[i]=ha_open;
      ExtCBuffer[i]=ha_close;
      switch(MAMethod){
         case MODE_EMA:
            ma = ExponentialMA(i, MAPeriod, ExtMABuffer[i-1], ExtCBuffer);
            break;
         case MODE_SMA:
            ma = SimpleMA(i, MAPeriod, ExtCBuffer);
            break;
         case MODE_SMMA:
            ma = SmoothedMA(i, MAPeriod, ExtMABuffer[i-1], ExtCBuffer);
            break;
         case MODE_LWMA:
            ma = LinearWeightedMA(i, MAPeriod, ExtCBuffer);
            break;
         default:
           ma = 0;
           break;
      }
      ExtMABuffer[i]=ma;
      ExtMAColorBuffer[i]=0.0;

      //--- set candle color
      if(ha_open<ha_close)
         ExtColorBuffer[i]=0.0; // set color DodgerBlue
      else
         ExtColorBuffer[i]=1.0; // set color Red
     }
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
