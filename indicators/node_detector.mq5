//--- indicator settings
#property indicator_chart_window
#property indicator_buffers   13
#property indicator_plots     6

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrLightGray, clrGray, C'64,64,0', C'86,214,86', C'78,14,14', C'255,79,79'  // neutral trend; neutral trend node; bullish trend; node in bullish trend; bearish trend; node in bearish trend
#property indicator_label1    "Open;High;Low;Close"

#property indicator_type2 DRAW_NONE
#property indicator_label2    "BOS number"

#property indicator_type3 DRAW_NONE
#property indicator_label3    "Broken candle price"

#property indicator_type4 DRAW_NONE
#property indicator_label4    "Broken candle shift"

#property indicator_type5 DRAW_NONE
#property indicator_label5    "WinRate%"

#property indicator_type6 DRAW_NONE
#property indicator_label6    "ProfitPoints"

input bool backtesting = false;
input int n_trend_change_win_rate = 10;

//--- indicator buffers
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];
double ExtColorBuffer[];
double ExtWinRateBuffer[];
double ExtProfitPointsbuffer[];
double ExtTrendbuffer[]; // 0 neutral, 1 bullish, 2 bearish
double ExtNodeBuffer[]; // 0 neutral, 1 top, 2 bottom
double ExtNodeBrokenBuffer[];
double ExtBosBuffer[];
double ExtBosPriceBuffer[];
double ExtBosShiftBuffer[];

int NodeIndex[];
int TrendChangedIndex[];

#define ISGREEN(j) close[j]>open[j]
#define ISRED(j) close[j]<open[j]
#define SPREAD(j) MathAbs(high[j]-low[j])
#define BODYRATIO(j) MathAbs(close[j]-open[j])/MathAbs(high[j]-low[j])

//double bicandles_min_body_ratio = 0.3;
//double midcandle_max_body_ratio = 0.7;

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
   SetIndexBuffer(5,ExtBosBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,ExtBosPriceBuffer,INDICATOR_DATA);
   SetIndexBuffer(7,ExtBosShiftBuffer,INDICATOR_DATA);
   SetIndexBuffer(8,ExtWinRateBuffer,INDICATOR_DATA); 
   SetIndexBuffer(9,ExtProfitPointsbuffer,INDICATOR_DATA); 
   SetIndexBuffer(10,ExtTrendbuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,ExtNodeBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,ExtNodeBrokenBuffer,INDICATOR_CALCULATIONS); 
   
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- sets first bar from what index will be drawn
   IndicatorSetString(INDICATOR_SHORTNAME,"Node_detector");
//--- sets drawing line empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   
   //ChartSetInteger(0, CHART_MODE, CHART_LINE);
   //color clr = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   //ChartSetInteger(0, CHART_COLOR_CHART_LINE, clr);
   ArrayFree(NodeIndex);
   ArrayFree(TrendChangedIndex);
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
   int start;                
   if(prev_calculated==0){
      ExtLBuffer[0]=low[0];
      ExtHBuffer[0]=high[0];
      ExtOBuffer[0]=open[0];
      ExtCBuffer[0]=close[0];
      ExtColorBuffer[0]=0;
      ExtTrendbuffer[0]=0;
      ExtNodeBuffer[0]=0;
      ExtNodeBrokenBuffer[0]=0;
      ExtBosBuffer[0]=0;
      start = 1;
   }else{
      start = prev_calculated - 2;
   } 

   for(int i=start; i<rates_total && !IsStopped(); i++){
      // update candle price
      ExtLBuffer[i]=low[i];
      ExtHBuffer[i]=high[i];
      ExtOBuffer[i]=open[i];
      ExtCBuffer[i]=close[i];    
      if(i<10) continue; 
      if(i==rates_total-1) continue;  // dont further analyze the unclosed candle
      if(ExtTrendbuffer[i]>0) continue;
            
      //--------------------------------
      //-------detect nodes-------------
      //--------------------------------
      ExtNodeBuffer[i] = 0; 
      ExtNodeBrokenBuffer[i] = 0;

      int jnode=i-1;
      bool top = false;
      bool bottom = false;                  
      
      if(ISGREEN(jnode+1) && ISRED(jnode) && ISGREEN(jnode-1) && close[jnode+1]>close[jnode-1] && low[jnode]>open[jnode-1] && high[jnode]<close[jnode+1] && MathAbs(high[jnode-2]-low[jnode-1])/SPREAD(jnode-1)<0.7){
         bottom = true;
      }
      if(ISRED(jnode+1) && ISGREEN(jnode) && ISRED(jnode-1) && close[jnode+1]<close[jnode-1] && high[jnode]<open[jnode-1] && low[jnode]>close[jnode+1] && MathAbs(low[jnode-2]-high[jnode-1])/SPREAD(jnode-1)<0.7){
         top = true;
      }
      
      if(top) ExtNodeBuffer[jnode] = 1;
      if(bottom) ExtNodeBuffer[jnode] = 2;
      if(top || bottom){
         int nnodes = ArraySize(NodeIndex);
         ArrayResize(NodeIndex, nnodes+1);
         NodeIndex[nnodes] = jnode;    
         ExtColorBuffer[jnode] = ExtTrendbuffer[jnode]*2 + 1;
      }

            
      //--------------------------------
      //-------detect choch and bos-----
      //--------------------------------
      if(ExtNodeBuffer[i-1]==0){
         ExtTrendbuffer[i] = ExtTrendbuffer[i-1];   
         ExtBosBuffer[i] = ExtBosBuffer[i-1];
         ExtBosPriceBuffer[i] = 0;
         ExtBosShiftBuffer[i] = 0;
      }else if(ExtNodeBuffer[i-1]==1){
         ExtTrendbuffer[i] = 2;
         if(ExtTrendbuffer[i-1]!=2) ExtBosBuffer[i] = 1;
         else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
         ExtBosPriceBuffer[i] = low[i-1];
         ExtBosShiftBuffer[i] = 1;
      }else if(ExtNodeBuffer[i-1]==2){
         ExtTrendbuffer[i] = 1;
         if(ExtTrendbuffer[i-1]!=1) ExtBosBuffer[i] = 1;
         else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
         ExtBosPriceBuffer[i] = high[i-1];
         ExtBosShiftBuffer[i] = 1;
      }
      
      int nnodes = ArraySize(NodeIndex);     
      for(int j=0;j<nnodes;j++){
         int nindex = NodeIndex[j];   
         if(ExtNodeBrokenBuffer[nindex]==1) continue;     
         if(ExtNodeBuffer[nindex]==1){
            if(close[i]>high[nindex]){
               ExtTrendbuffer[i] = 1;
               ExtNodeBrokenBuffer[nindex] = 1;
               if(ExtTrendbuffer[i-1]!=1) ExtBosBuffer[i] = 1;
               else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
               ExtBosPriceBuffer[i] = high[nindex];
               ExtBosShiftBuffer[i] = i-nindex;
            }            
         }else if(ExtNodeBuffer[nindex]==2){
            if(close[i]<low[nindex]){
               ExtTrendbuffer[i] = 2;
               ExtNodeBrokenBuffer[nindex] = 1;
               if(ExtTrendbuffer[i-1]!=2) ExtBosBuffer[i] = 1;
               else ExtBosBuffer[i] = ExtBosBuffer[i-1]+1;
               ExtBosPriceBuffer[i] = low[nindex];
               ExtBosShiftBuffer[i] = i-nindex;
            }
         }
      }
      ExtColorBuffer[i] = 2*ExtTrendbuffer[i];
            
      //--- update win rate
      if(backtesting){
         int ntrendchanged = ArraySize(TrendChangedIndex);
         if(ExtTrendbuffer[i] != ExtTrendbuffer[i-1]){
            ArrayResize(TrendChangedIndex, ntrendchanged+1);
            TrendChangedIndex[ntrendchanged] = i;    
            ntrendchanged++;   
         }
         double wins = 0;
         double profit_points = 0;
         for(int k=ntrendchanged-n_trend_change_win_rate-1;k<ntrendchanged-1;k++){
            if(k<0) continue;
            int startindex = TrendChangedIndex[k];
            int endindex = TrendChangedIndex[k+1];
            if(close[endindex]>close[startindex] && ExtTrendbuffer[startindex]==1) wins++;
            if(close[endindex]<close[startindex] && ExtTrendbuffer[startindex]==2) wins++;
            if(ExtTrendbuffer[startindex]==1) profit_points += (close[endindex] - close[startindex]) / _Point;
            if(ExtTrendbuffer[startindex]==2) profit_points += (close[startindex] - close[endindex]) / _Point;
         }
         double winrate = NormalizeDouble(100*wins/n_trend_change_win_rate, 1);
         ExtWinRateBuffer[i] = winrate;
         ExtProfitPointsbuffer[i] = profit_points;
      }      
   }
   //---
   return(rates_total);
}
//+------------------------------------------------------------------+