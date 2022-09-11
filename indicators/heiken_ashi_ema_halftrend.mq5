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
#property indicator_buffers   18
#property indicator_plots     7

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    Green, Red
#property indicator_label1    "Heiken Ashi Candles"

#property indicator_type2     DRAW_COLOR_LINE
#property indicator_color2    Blue
#property indicator_label2    "MA"

#property indicator_label3 "UP"
#property indicator_color3 Purple  // up[] DodgerBlue
#property indicator_type3  DRAW_LINE
#property indicator_width3 2

#property indicator_label4 "DN"
#property indicator_color4 Red       // down[]
#property indicator_type4  DRAW_LINE
#property indicator_width4 2

#property indicator_label5 "ATR-LH"
#property indicator_color5 DodgerBlue,Red  // atrlo[],atrhi[]
#property indicator_type5  DRAW_COLOR_HISTOGRAM2
#property indicator_width5 1

#property indicator_label6 "ARR-UP"
#property indicator_color6 DodgerBlue  // arrup[]
#property indicator_type6  DRAW_ARROW
#property indicator_width6 1

#property indicator_label7 "ARR-DOWN"
#property indicator_color7 Red  // arrdwn[]
#property indicator_type7  DRAW_ARROW
#property indicator_width7 1


input ENUM_MA_METHOD MAMethod = MODE_EMA;
input int    MAPeriod=10;

input int    Amplitude        = 3;
input int    ChannelDeviation = 2;   // neeeeds to beee codeeeeeeeeeeeed!!!!!!!!!!!!!!!!!!!!
input bool   ShowBars         = false;
input bool   ShowArrows       = false;
input bool   alertsOn         = false;
input bool   alertsOnCurrent  = false;
input bool   alertsMessage    = false;
input bool   alertsSound      = false;
input bool   alertsEmail      = false;

//--- indicator buffers
double HAO[], HAH[], HAL[], HAC[], HAClr[], MA[], MAClr[];

bool nexttrend;
double minhighprice, maxlowprice;
double up[], down[], atrlo[], atrhi[], atrclr[], trend[];
double arrup[], arrdwn[];
//int ind_mahi, ind_malo, ind_atr;
double iMAHigh[], iMALow[], iATRx[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,HAO,INDICATOR_DATA);
   SetIndexBuffer(1,HAH,INDICATOR_DATA);
   SetIndexBuffer(2,HAL,INDICATOR_DATA);
   SetIndexBuffer(3,HAC,INDICATOR_DATA);
   SetIndexBuffer(4,HAClr,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5,MA,INDICATOR_DATA);
   SetIndexBuffer(6,MAClr,INDICATOR_COLOR_INDEX);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   //ArraySetAsSeries(ExtOBuffer, true);
   //ArraySetAsSeries(ExtHBuffer, true);
   //ArraySetAsSeries(ExtLBuffer, true);
   //ArraySetAsSeries(ExtCBuffer, true);
   //ArraySetAsSeries(ExtColorBuffer, true);
   //ArraySetAsSeries(ExtMABuffer, true);
   //ArraySetAsSeries(ExtMAColorBuffer, true);
   
   
   SetIndexBuffer(0+7, up, INDICATOR_DATA);
   SetIndexBuffer(1+7, down, INDICATOR_DATA);
   SetIndexBuffer(2+7, atrlo, INDICATOR_DATA);
   SetIndexBuffer(3+7, atrhi, INDICATOR_DATA);
   SetIndexBuffer(4+7, atrclr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5+7, arrup, INDICATOR_DATA);
   SetIndexBuffer(6+7, arrdwn, INDICATOR_DATA);
   SetIndexBuffer(7+7, trend, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8+7, iMAHigh, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9+7, iMALow, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10+7, iATRx, INDICATOR_CALCULATIONS);
   PlotIndexSetDouble(0+2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1+2, PLOT_EMPTY_VALUE, 0.0);
   //ArraySetAsSeries(up, true);
   //ArraySetAsSeries(down, true);
   //ArraySetAsSeries(atrlo, true);
   //ArraySetAsSeries(atrhi, true);
   //ArraySetAsSeries(atrclr, true);
   //ArraySetAsSeries(arrup, true);
   //ArraySetAsSeries(arrdwn, true);
   //ArraySetAsSeries(trend, true);
   //ArraySetAsSeries(iMAHigh, true);
   //ArraySetAsSeries(iMALow, true);
   //ArraySetAsSeries(iATRx, true);
   if(!ShowBars)
   {
      PlotIndexSetInteger(2+2,PLOT_LINE_COLOR,0,clrNONE); 
      PlotIndexSetInteger(2+2,PLOT_LINE_COLOR,1,clrNONE); 
   }
   else
   {
      PlotIndexSetInteger(2+2,PLOT_LINE_COLOR,0,clrDodgerBlue); 
      PlotIndexSetInteger(2+2,PLOT_LINE_COLOR,1,clrRed); 
   }
   if(!ShowArrows)
   {
      PlotIndexSetInteger(3+2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4+2, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   else
   {
      PlotIndexSetInteger(3+2, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(4+2, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(3+2, PLOT_ARROW, 225);     //233
      PlotIndexSetInteger(4+2, PLOT_ARROW, 226);     //234
   }
   //ind_mahi = iMA(NULL, 0, Amplitude, 0, MODE_SMA, PRICE_HIGH);
   //ind_malo = iMA(NULL, 0, Amplitude, 0, MODE_SMA, PRICE_LOW);
   //ind_atr = iATR(NULL, 0, 100);
   //if(ind_mahi == INVALID_HANDLE || ind_mahi == INVALID_HANDLE || ind_atr == INVALID_HANDLE)
   //{
   //   PrintFormat("Failed to create handle of the indicators, error code %d", GetLastError());
   //   return(INIT_FAILED);
   //}
   nexttrend = 0;
   minhighprice = iHigh(NULL, 0, Bars(NULL, 0) - 1);
   maxlowprice = iLow(NULL, 0, Bars(NULL, 0) - 1);
   return (INIT_SUCCEEDED);
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
      switch(MAMethod){
         case MODE_EMA:
            ma = ExponentialMA(i, MAPeriod, ExtMABuffer[i-1], close);
            break;
         case MODE_SMA:
            ma = SimpleMA(i, MAPeriod, close);
            break;
         case MODE_SMMA:
            ma = SmoothedMA(i, MAPeriod, ExtMABuffer[i-1], close);
            break;
         case MODE_LWMA:
            ma = LinearWeightedMA(i, MAPeriod, close);
            break;
         default:
           ma = 0;
           break;
      }
      ExtLBuffer[i]=ha_low;
      ExtHBuffer[i]=ha_high;
      ExtOBuffer[i]=ha_open;
      ExtCBuffer[i]=ha_close;
      ExtMABuffer[i]=ma;
      ExtMAColorBuffer[i]=0.0;

      //--- set candle color
      if(ha_open<ha_close)
         ExtColorBuffer[i]=0.0; // set color DodgerBlue
      else
         ExtColorBuffer[i]=1.0; // set color Red
     }
//---
   int i, limit, to_copy;
   double atr, lowprice_i, highprice_i, lowma, highma;
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   if(prev_calculated > rates_total || prev_calculated < 0) to_copy = rates_total;
   else
   {
      to_copy = rates_total - prev_calculated;
      if(prev_calculated > 0)
         to_copy += 10;
   }
   if(!RefreshBuffers(iMAHigh, iMALow, iATRx, ind_mahi, ind_malo, ind_atr, to_copy))
      return(0);
   if(prev_calculated == 0)
      limit = rates_total - 2;
   else
      limit = rates_total - prev_calculated + 1;
   for(i = limit; i >= 0; i--)
   {
      lowprice_i = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, Amplitude, i));
      highprice_i = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, Amplitude, i));
      lowma = NormalizeDouble(iMALow[i], _Digits);
      highma = NormalizeDouble(iMAHigh[i], _Digits);
      trend[i] = trend[i + 1];
      atr = iATRx[i] / 2;
      arrup[i]  = EMPTY_VALUE;
      arrdwn[i] = EMPTY_VALUE;
      if(trend[i + 1] != 1.0)
      {
         maxlowprice = MathMax(lowprice_i, maxlowprice);
         if(highma < maxlowprice && close[i] < low[i + 1])
         {
            trend[i] = 1.0;
            nexttrend = 0;
            minhighprice = highprice_i;
         }
      }
      else
      {
         minhighprice = MathMin(highprice_i, minhighprice);
         if(lowma > minhighprice && close[i] > high[i + 1])
         {
            trend[i] = 0.0;
            nexttrend = 1;
            maxlowprice = lowprice_i;
         }
      }
      //---
      if(trend[i] == 0.0)
      {
         if(trend[i + 1] != 0.0)
         {
            up[i] = down[i + 1];
            up[i + 1] = up[i];
            arrup[i] = up[i] - 2 * atr;
         }
         else
         {
            up[i] = MathMax(maxlowprice, up[i + 1]);
         }
         atrhi[i] = up[i] - atr;
         atrlo[i] = up[i];
         atrclr[i] = 0;
         down[i] = 0.0;
      }
      else
      {
         if(trend[i + 1] != 1.0)
         {
            down[i] = up[i + 1];
            down[i + 1] = down[i];
            arrdwn[i] = down[i] + 2 * atr;
         }
         else
         {
            down[i] = MathMin(minhighprice, down[i + 1]);
         }
         atrhi[i] = down[i] + atr;
         atrlo[i] = down[i];
         atrclr[i] = 1;
         up[i] = 0.0;
      }
   }
   manageAlerts();
   return (rates_total);
}

//+------------------------------------------------------------------+
//| Filling indicator buffers from the indicators                    |
//+------------------------------------------------------------------+
bool RefreshBuffers(double &hi_buffer[],
                    double &lo_buffer[],
                    double &atr_buffer[],
                    int hi_handle,
                    int lo_handle,
                    int atr_handle,
                    int amount
                   )
{
//--- reset error code
   ResetLastError();
//--- fill a part of the iMACDBuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(hi_handle, 0, 0, amount, hi_buffer) < 0)
   {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the MaHigh indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
//--- fill a part of the SignalBuffer array with values from the indicator buffer that has index 1
   if(CopyBuffer(lo_handle, 0, 0, amount, lo_buffer) < 0)
   {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the MaLow indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
//--- fill a part of the StdDevBuffer array with values from the indicator buffer
   if(CopyBuffer(atr_handle, 0, 0, amount, atr_buffer) < 0)
   {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the ATR indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
//--- everything is fine
   return(true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void manageAlerts()
{
   int whichBar;
   if (alertsOn)
   {
      if (alertsOnCurrent)
         whichBar = 0;
      else
         whichBar = 1;
      if (arrup[whichBar]  != EMPTY_VALUE) doAlert(whichBar, "up");
      if (arrdwn[whichBar] != EMPTY_VALUE) doAlert(whichBar, "down");
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void doAlert(int forBar, string doWhat)
{
   static string   previousAlert = "nothing";
   static datetime previousTime;
   string message;
   if (previousAlert != doWhat || previousTime != iTime(NULL, 0, forBar))
   {
      previousAlert  = doWhat;
      previousTime   = iTime(NULL, 0, forBar);
      message = StringFormat("%s at %s", Symbol(), TimeToString(TimeLocal(), TIME_SECONDS), " HalfTrend signal ", doWhat);
      if (alertsMessage) Alert(message);
      if (alertsEmail)   SendMail(Symbol(), StringFormat("HalfTrend %s", message));
      if (alertsSound)   PlaySound("alert2.wav");
   }
}

//+------------------------------------------------------------------+
