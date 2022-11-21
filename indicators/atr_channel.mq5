#property description "Average True Range Channel"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   3

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrGreen, clrRed
#property indicator_label1    "HAO;HAH;HAL;HAC"

#property indicator_type2   DRAW_LINE
#property indicator_color2  DodgerBlue
#property indicator_label2  "ATR-HIGH"

#property indicator_type3   DRAW_LINE
#property indicator_color3  DodgerBlue
#property indicator_label3  "ATR-LOW"
//--- input parameters
input bool UseHeikenAshiCandles = false;
input int InpAtrPeriod=100;  // ATR period
input double InpAtrChannelDeviation=2; // ATR channel deviation
//--- indicator buffers
double HAO[], HAH[], HAL[], HAC[], HAClr[]; // heiken ashi candles
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
   SetIndexBuffer(0, HAO, INDICATOR_DATA);
   SetIndexBuffer(1, HAH, INDICATOR_DATA);
   SetIndexBuffer(2, HAL, INDICATOR_DATA);
   SetIndexBuffer(3, HAC, INDICATOR_DATA);
   SetIndexBuffer(4, HAClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, atrhigh, INDICATOR_DATA);
   SetIndexBuffer(6, atrlow, INDICATOR_DATA);
   SetIndexBuffer(7, ExtATRBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ExtTRBuffer, INDICATOR_CALCULATIONS);
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpAtrPeriod);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,InpAtrPeriod);
   
   if(UseHeikenAshiCandles){
      ChartSetInteger(0, CHART_MODE, CHART_LINE);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE, ChartGetInteger(0, CHART_COLOR_BACKGROUND));
   }
  }

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
      HAL[0]=low[0];
      HAH[0]=high[0];
      HAO[0]=open[0];
      HAC[0]=close[0];
      start=1;
   }else{
      start=prev_calculated-1;
   }

   for(int i=start;i<rates_total;i++){
      //-- calculate heiken ashi candles
      if(UseHeikenAshiCandles){
         HAO[i] = (HAO[i-1]+HAC[i-1])/2;
         HAC[i] = (open[i]+high[i]+low[i]+close[i])/4;
         HAH[i] = MathMax(high[i],MathMax(HAO[i],HAC[i]));
         HAL[i] = MathMin(low[i],MathMin(HAO[i],HAC[i]));
      }else{
         HAO[i] = open[i];
         HAC[i] = close[i];
         HAH[i] = high[i];
         HAL[i] = low[i];   
      }
      HAO[i] = NormalizeDouble(HAO[i], _Digits);
      HAC[i] = NormalizeDouble(HAC[i], _Digits);
      HAH[i] = NormalizeDouble(HAH[i], _Digits);
      HAL[i] = NormalizeDouble(HAL[i], _Digits);
      HAClr[i]=HAO[i]<HAC[i]?0.0:1.0; // set candle color
   }
   calculate_atr(rates_total, prev_calculated, time, HAO, HAH, HAL, HAC, tick_volume, volume, spread);
   return (rates_total);
}      
//+------------------------------------------------------------------+
//| Average True Range                                               |
//+------------------------------------------------------------------+
int calculate_atr(const int rates_total,
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
