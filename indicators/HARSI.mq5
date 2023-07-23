#property description "HA candles with RSI"
//--- indicator settings
#property indicator_separate_window
#property indicator_minimum -50
#property indicator_maximum 50
#property indicator_level1 -20
#property indicator_level2 0
#property indicator_level3 20
#property indicator_buffers 7
#property indicator_plots   2

#property indicator_type1     DRAW_COLOR_CANDLES
#property indicator_color1    clrGreen, clrRed
#property indicator_label1    "HAO;HAH;HAL;HAC"

#property indicator_type2     DRAW_COLOR_LINE
#property indicator_color2    clrYellow
#property indicator_label2    "RSI"

//--- input parameters
input int harsi_length=14; // RSI length for HA candles calculation
input int harsi_smoothing_length = 7;
input int rsi_length=7; // RSI length for RSI plot (source=hl2)
input bool rsi_smoothing=true;
input bool enable_alert = false;
//--- indicator buffers
double HAO[], HAH[], HAL[], HAC[], HAClr[]; // heiken ashi candles
double RSI[], RSIClr[];  // RSI line based on ohlc4
int rsi_hl2_handle, rsi_o_handle, rsi_h_handle, rsi_l_handle, rsi_c_handle;
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
   SetIndexBuffer(6, RSIClr, INDICATOR_COLOR_INDEX);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
//--- sets first bar from what index will be drawn
   //PlotIndexSetInteger(0,PLOT_DRAW_BEGIN, MathMax(harsi_length, rsi_length));
   rsi_hl2_handle = iRSI(_Symbol, _Period, rsi_length, PRICE_MEDIAN);
   rsi_o_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_OPEN);
   rsi_h_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_HIGH);
   rsi_l_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_LOW);
   rsi_c_handle = iRSI(_Symbol, _Period, harsi_length, PRICE_CLOSE);
  }

void OnDeinit(){
   IndicatorRelease(rsi_hl2_handle);
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
      
      double rsiohlc4[1];
      CopyBuffer(rsi_hl2_handle, 0, rates_total-i-1, 1, rsiohlc4);
      rsiohlc4[0] -= 50;
      if(rsi_smoothing) rsiohlc4[0] = (rsiohlc4[0]+RSI[i-1])/2;
      RSI[i] = NormalizeDouble(rsiohlc4[0], 1);
      RSIClr[i] = 0.0;
      
      if(HAClr[i-1]!=HAClr[i-2] && i==rates_total-2 && enable_alert) Alert(_Symbol + ": HARSI color changed.");
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
