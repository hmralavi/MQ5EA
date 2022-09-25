#include <MovingAverages.mqh>

#property indicator_chart_window
#property indicator_buffers   18
#property indicator_plots     6

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrGreen, clrRed
#property indicator_label1    "HAO;HAH;HAL;HAC"

#property indicator_type2     DRAW_COLOR_LINE
#property indicator_color2    clrBlue
#property indicator_label2    "MA"

#property indicator_label3 "TrendLine"
#property indicator_color3 clrDodgerBlue, clrOrange // up[] DodgerBlue
#property indicator_type3  DRAW_COLOR_LINE
#property indicator_width3 2

#property indicator_label4 "ATR Line"
#property indicator_color4 clrGray // atrlo[],atrhi[]
#property indicator_type4  DRAW_COLOR_LINE
#property indicator_width4 1

#property indicator_label5 "Arrow-UP"
#property indicator_color5 clrDodgerBlue  // arrup[]
#property indicator_type5  DRAW_ARROW
#property indicator_width5 1

#property indicator_label6 "Arrow-DOWN"
#property indicator_color6 clrRed  // arrdwn[]
#property indicator_type6  DRAW_ARROW
#property indicator_width6 1


input bool UseHeikenAshiCandles = true;
input ENUM_MA_METHOD MAMethod = MODE_EMA;
input int    MAPeriod         = 200;
input int    Amplitude        = 3;
input int    AtrPeriod        = 100;
input double    ChannelDeviation = 2.0; 
input bool   ShowAtr          = true;
input bool   ShowArrows       = false;
input bool   alertsOn         = false;
input bool   alertsOnCurrent  = false;
input bool   alertsMessage    = false;
input bool   alertsSound      = false;
input bool   alertsEmail      = false;

//--- indicator buffers
double HAO[], HAH[], HAL[], HAC[], HAClr[]; // heiken ashi candles
double MA[], MAClr[];  // MA line 
double updown[], updownclr[], trend[];  // halftrend line
double atr[], atrclr[];  // atr line
double arrup[], arrdwn[];  // arrow shapes
double iMAHigh[], iMALow[], iATRx[], iTRx[];  //  indicator calculations buffers
//--- some variables
bool nexttrend;
double minhighprice, maxlowprice;


void OnInit()
  {
   SetIndexBuffer(0, HAO, INDICATOR_DATA);
   SetIndexBuffer(1, HAH, INDICATOR_DATA);
   SetIndexBuffer(2, HAL, INDICATOR_DATA);
   SetIndexBuffer(3, HAC, INDICATOR_DATA);
   SetIndexBuffer(4, HAClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, MA, INDICATOR_DATA);
   SetIndexBuffer(6, MAClr, INDICATOR_COLOR_INDEX);   
   SetIndexBuffer(7, updown, INDICATOR_DATA);
   SetIndexBuffer(8, updownclr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(9, atr, INDICATOR_DATA);
   SetIndexBuffer(10, atrclr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(11, arrup, INDICATOR_DATA);
   SetIndexBuffer(12, arrdwn, INDICATOR_DATA);
   SetIndexBuffer(13, trend, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, iMAHigh, INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, iMALow, INDICATOR_CALCULATIONS);
   SetIndexBuffer(16, iATRx, INDICATOR_CALCULATIONS);
   SetIndexBuffer(17, iTRx, INDICATOR_CALCULATIONS);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   
   if(UseHeikenAshiCandles){
      ChartSetInteger(0, CHART_MODE, CHART_LINE);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE, ChartGetInteger(0, CHART_COLOR_BACKGROUND));
   }

   if(!ShowAtr){
      PlotIndexSetInteger(3,PLOT_LINE_COLOR,0,clrNONE); 
   }else{
      PlotIndexSetInteger(3,PLOT_LINE_COLOR,0,clrGray); 
   }
   if(!ShowArrows){
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
   }else{
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(4, PLOT_ARROW, 225);     //233
      PlotIndexSetInteger(5, PLOT_ARROW, 226);     //234
   }
   nexttrend = 0;
   minhighprice = iHigh(NULL, 0, 0);
   maxlowprice = iLow(NULL, 0, 0);
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
      MA[0]=close[0];
      iMAHigh[0]=high[0];
      iMALow[0]=low[0];
      trend[0]=0.0;
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
      
      //--- calculate MAs
      iMAHigh[i] = SimpleMA(i, Amplitude, HAH);
      iMALow[i] = SimpleMA(i, Amplitude, HAL);
      switch(MAMethod){
         case MODE_EMA:
            MA[i] = ExponentialMA(i, MAPeriod, MA[i-1], HAC);
            break;
         case MODE_SMA:
            MA[i] = SimpleMA(i, MAPeriod, HAC);
            break;
         case MODE_SMMA:
            MA[i] = SmoothedMA(i, MAPeriod, MA[i-1], HAC);
            break;
         case MODE_LWMA:
            MA[i] = LinearWeightedMA(i, MAPeriod, HAC);
            break;
         default:
           MA[i] = 0;
           break;
      }     
      MA[i] = NormalizeDouble(MA[i], _Digits);
      MAClr[i]=0.0;
   }

   calculate_atr(rates_total, prev_calculated, time, HAO, HAH, HAL, HAC, tick_volume, volume, spread);

   //---  calculate halftrend line
   double atr_, lowprice_i, highprice_i, lowma, highma;
   for(int i=start;i<rates_total;i++){
      lowprice_i = HAL[i];
      highprice_i = HAH[i];
      for(int j=MathMax(i-Amplitude+1,0);j<i;j++){
         if(HAL[j]<lowprice_i) lowprice_i = HAL[j];
         if(HAH[j]>highprice_i) highprice_i = HAH[j];
      }
      lowma = NormalizeDouble(iMALow[i], _Digits);
      highma = NormalizeDouble(iMAHigh[i], _Digits);
      trend[i] = trend[i - 1];
      atr_ = ChannelDeviation * iATRx[i] / 2;
      arrup[i]  = EMPTY_VALUE;
      arrdwn[i] = EMPTY_VALUE;
      if(trend[i - 1] != 1.0){
         maxlowprice = MathMax(lowprice_i, maxlowprice);
         if(highma < maxlowprice && HAC[i] < HAL[i - 1]){
            trend[i] = 1.0;
            nexttrend = 0;
            minhighprice = highprice_i;
         }
      }else{
         minhighprice = MathMin(highprice_i, minhighprice);
         if(lowma > minhighprice && HAC[i] > HAH[i - 1]){
            trend[i] = 0.0;
            nexttrend = 1;
            maxlowprice = lowprice_i;
         }
      }
      //---
      if(trend[i] == 0.0){
         if(trend[i - 1] != 0.0){
            updown[i] = updown[i-1];
            arrup[i] = updown[i] - 2 * atr_;
         }else{
            updown[i] = MathMax(maxlowprice, updown[i-1]);
         }
         updownclr[i] = 0.0;
         atr[i] = updown[i] - atr_;
      }else{
         if(trend[i - 1] != 1.0){
            updown[i] = updown[i-1];            
            arrdwn[i] = updown[i] + 2 * atr_;
         }else{
            updown[i] = MathMin(minhighprice, updown[i-1]);
         }
         updownclr[i] = 1.0;         
         atr[i] = updown[i] + atr_;
      }
      updown[i] = NormalizeDouble(updown[i], _Digits);
      atr[i] = NormalizeDouble(atr[i], _Digits);
      atrclr[i] = 0.0;
   }
   //---
   manageAlerts();
   return (rates_total);
}

//+------------------------------------------------------------------+
//|         calculate ATR                                            |
//+------------------------------------------------------------------+

void calculate_atr(const int rates_total,
                  const int prev_calculated,
                  const datetime &time[],
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  const long &tick_volume[],
                  const long &volume[],
                  const int &spread[]){
   if(rates_total<=AtrPeriod)
      return;
   int start;
   //--- preliminary calculations
   if(prev_calculated==0)
     {
      iTRx[0]=0.0;
      iATRx[0]=0.0;
      //--- filling out the array of True Range values for each period
      for(int i=1; i<rates_total && !IsStopped(); i++)
         iTRx[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      //--- first AtrPeriod values of the indicator are not calculated
      double firstValue=0.0;
      for(int i=1; i<=AtrPeriod; i++)
        {
         iATRx[i]=0.0;
         firstValue+=iTRx[i];
        }
      //--- calculating the first value of the indicator
      firstValue/=AtrPeriod;
      iATRx[AtrPeriod]=firstValue;
      start=AtrPeriod+1;
     }
   else
      start=prev_calculated-1;
   //--- the main loop of calculations
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      iTRx[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      iATRx[i]=iATRx[i-1]+(iTRx[i]-iTRx[i-AtrPeriod])/AtrPeriod;
     }
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
