#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   10

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2
#property indicator_label1  "SSL Upper"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDeepPink
#property indicator_width2  2
#property indicator_label2  "SSL Lower"

#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDeepSkyBlue
#property indicator_width3  4
#property indicator_label3  "SSL Buy"

#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  4
#property indicator_label4  "SSL sell"

#property indicator_type5 DRAW_NONE
#property indicator_label5    "SSL Trend Length"

#property indicator_type6 DRAW_NONE
#property indicator_label6    "SSL Average Trend Length"

#property indicator_type7 DRAW_NONE
#property indicator_label7    "SSL WinRate%"

#property indicator_type8 DRAW_NONE
#property indicator_label8    "SSL Profit Points"

#property indicator_type9 DRAW_NONE
#property indicator_label9    "SSL Loss Points"

#property indicator_type10 DRAW_NONE
#property indicator_label10    "SSL Net Profit Points"


input uint   period=13;           // Moving averages period;
input bool   NRTR=true;           // NRTR
input int    min_breaking_points=0;   // minimum breaking points
input bool   multiple_entries=false;  // Multiple entry signals
input int    backtest_ntrends=5;  // Number of previous trends for backtesting

double ExtMapBufferUp[];
double ExtMapBufferDown[];
double ExtMapBufferUp1[];
double ExtMapBufferDown1[];
double ExtTrendLength[];
double ExtAverageTrendLength[];
double ExtWinRate[];
double ExtProfitPoints[];
double ExtLossPoints[];
double ExtNetProfitPoints[];

#define RESET  0 // The constant for returning the indicator recalculation command to the terminal

int HMA_Handle,LMA_Handle;
int min_rates_total;

int OnInit()
  {
   HMA_Handle=iMA(NULL,0,period,0,MODE_LWMA,PRICE_HIGH);
   if(HMA_Handle==INVALID_HANDLE)
     {
      Print(" Failed to get handle of the HMA indicator");
      return INIT_FAILED;
     }

   LMA_Handle=iMA(NULL,0,period,0,MODE_LWMA,PRICE_LOW);
   if(LMA_Handle==INVALID_HANDLE)
     {
      Print(" Failed to get handle of the LMA indicator");
      return INIT_FAILED;
     }

   min_rates_total=int(period+1);

   SetIndexBuffer(0,ExtMapBufferUp,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
   ArraySetAsSeries(ExtMapBufferUp,true);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   SetIndexBuffer(1,ExtMapBufferDown,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
   ArraySetAsSeries(ExtMapBufferDown,true);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   SetIndexBuffer(2,ExtMapBufferUp1,INDICATOR_DATA);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,min_rates_total);
   ArraySetAsSeries(ExtMapBufferUp1,true);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(2,PLOT_ARROW,159);

   SetIndexBuffer(3,ExtMapBufferDown1,INDICATOR_DATA);
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,min_rates_total);
   ArraySetAsSeries(ExtMapBufferDown1,true);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(3,PLOT_ARROW,159);
   
   SetIndexBuffer(4,ExtTrendLength,INDICATOR_DATA);
   SetIndexBuffer(5,ExtAverageTrendLength,INDICATOR_DATA);
   SetIndexBuffer(6,ExtWinRate,INDICATOR_DATA);
   SetIndexBuffer(7,ExtProfitPoints,INDICATOR_DATA);
   SetIndexBuffer(8,ExtLossPoints,INDICATOR_DATA);
   SetIndexBuffer(9,ExtNetProfitPoints,INDICATOR_DATA);

   string shortname;
   StringConcatenate(shortname,"SSL(",period,")");
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   return INIT_SUCCEEDED;
  }

int OnCalculate(const int rates_total,    // amount of history in bars at the current tick
                const int prev_calculated,// amount of history in bars at the previous tick
                const datetime &time[],
                const double &open[],
                const double& high[],     // price array of maximums of price for the calculation of indicator
                const double& low[],      // price array of minimums of price for the calculation of indicator
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {

   if(BarsCalculated(HMA_Handle)<rates_total
      || BarsCalculated(LMA_Handle)<rates_total
      || rates_total<min_rates_total)
      return(RESET);

//---- declaration of local variables 
   double HMA[],LMA[];
   int limit,to_copy,bar,trend,Hld;
   static int trend_;

//---- indexing elements in arrays as in time series  
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(HMA,true);
   ArraySetAsSeries(LMA,true);

//---- calculation of the limit starting index for the bars recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0) // checking for the first start of the indicator calculation
     {
      limit=rates_total-min_rates_total-1;               // starting index for calculation of all bars
      trend_=0;
     }
   else
     {
      limit=rates_total-prev_calculated;                 // starting index for calculation of new bars
     }

   to_copy=limit+2;
//---- copy newly appeared data into the arrays
   if(CopyBuffer(HMA_Handle,0,0,to_copy,HMA)<=0) return(RESET);
   if(CopyBuffer(LMA_Handle,0,0,to_copy,LMA)<=0) return(RESET);

//---- restore values of the variables
   trend=trend_;

//---- main loop of the indicator calculation
   for(bar=limit; bar>=0; bar--)
     {
      ExtMapBufferUp[bar]=EMPTY_VALUE;
      ExtMapBufferDown[bar]=EMPTY_VALUE;
      ExtMapBufferUp1[bar]=EMPTY_VALUE;
      ExtMapBufferDown1[bar]=EMPTY_VALUE;

      if(close[bar]-min_breaking_points*_Point>=HMA[bar+1]) Hld=+1;
      else
        {
         if(close[bar]+min_breaking_points*_Point<=LMA[bar+1]) Hld=-1;
         else Hld=0;
        }
      if(Hld!=0) trend=Hld;
      if(trend==-1)
        {
         if(!NRTR || ExtMapBufferDown[bar+1]==EMPTY_VALUE) ExtMapBufferDown[bar]=HMA[bar+1];
         else if(ExtMapBufferDown[bar+1]!=EMPTY_VALUE) ExtMapBufferDown[bar]=MathMin(HMA[bar+1],ExtMapBufferDown[bar+1]);
        }
      else
        {

         if(!NRTR || ExtMapBufferUp[bar+1]==EMPTY_VALUE) ExtMapBufferUp[bar]=LMA[bar+1];
         else  if(ExtMapBufferUp[bar+1]!=EMPTY_VALUE) ExtMapBufferUp[bar]=MathMax(LMA[bar+1],ExtMapBufferUp[bar+1]);
        }

      if((ExtMapBufferUp[bar+1]==EMPTY_VALUE && ExtMapBufferUp[bar]!=EMPTY_VALUE) || (multiple_entries && ExtMapBufferUp[bar+1]!=EMPTY_VALUE && ExtMapBufferUp[bar]!=EMPTY_VALUE && low[bar]-0.5*min_breaking_points*_Point<=ExtMapBufferUp[bar] && ExtMapBufferUp1[bar+1]==EMPTY_VALUE)) ExtMapBufferUp1[bar]=ExtMapBufferUp[bar];
      if((ExtMapBufferDown[bar+1]==EMPTY_VALUE && ExtMapBufferDown[bar]!=EMPTY_VALUE) || (multiple_entries && ExtMapBufferDown[bar+1]!=EMPTY_VALUE && ExtMapBufferDown[bar]!=EMPTY_VALUE && high[bar]+0.5*min_breaking_points*_Point>=ExtMapBufferDown[bar] && ExtMapBufferDown1[bar+1]==EMPTY_VALUE)) ExtMapBufferDown1[bar]=ExtMapBufferDown[bar];

      if(bar) trend_=trend;
      
      
     }
//----     
   return(rates_total);
  }
//+------------------------------------------------------------------+
