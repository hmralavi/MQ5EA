/*
------------------------------------------------------------
EA made by hamid alavi.


Strategy:
   1- Find the trend using ema
   2- In bullish trend, wait for 3 consecutive red candles.
   3- If spread/volume is decreasing for the 3 candles and volumes are above average volume, enter buy position at end of the 3rd candle.


TODO:
   
-------------------------------------------------------------
*/

#property description "Volume & price spread divergence scalper"

input int n_candles = 3; // number of candles to analyze
input int ma1_period = 110;  // MA1 period.
input int ma2_period = 40;  // MA2 period.
input double lot_size = 0.01;  // Lot Size.
input double stop_loss = 30;  // stoploss offset to the candles high/low
input float take_profit = 50;  // take profit
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "17:00";        // session end (server time)    

int magic_number=12345;
int ma1_handle;
int ma2_handle;
int rsi_handle;

double sl;
double tp;

enum MarketTrendType{
   NEUTRAL=0,
   BULLISH=1,
   BEARISH=2
};

int OnInit(void)
{
   ma1_handle=iMA(_Symbol,_Period,ma1_period,0,MODE_EMA,PRICE_CLOSE);
   ma2_handle=iMA(_Symbol,_Period,ma2_period,0,MODE_EMA,PRICE_CLOSE);
   rsi_handle=iRSI(_Symbol,_Period,14,PRICE_CLOSE);
   if(ma1_handle<0 || ma2_handle<0)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(INIT_FAILED);
     }
     
   int digits_adjust=1;
   if(_Digits==2 || _Digits==5)
      digits_adjust=10;
   double m_adjusted_point=_Point*digits_adjust;

   sl=stop_loss*m_adjusted_point;
   tp=take_profit*m_adjusted_point;
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(ma1_handle);
   IndicatorRelease(ma2_handle);
   IndicatorRelease(rsi_handle);
}

void OnTick()
{
   if(Bars(_Symbol, _Period)<5*ma1_period){
      Alert("We have less than 5*ma1_period bars, EA will now exit!!");
      return;
   }
   
   // check if we have open positions
   if(open_position_exists()) return;
   
   // checking if the incomming tick is the begining of a new bar.
   if(!is_new_bar()) return;
   
   // check if we are in the allowed trading time
   if(!is_session_time_allowed()) return;
     
   // check the market trend
   MarketTrendType market_trend = check_market_trend();
   if(market_trend==NEUTRAL) return;
   
   // check volume & price spread divergence exists
   if(!is_volume_price_spread_divergence(market_trend==BULLISH)) return;
   
   // prepare order
   ENUM_ORDER_TYPE buy_or_sell = market_trend==BULLISH?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   MqlTradeRequest order = prepare_order(buy_or_sell);
   
   // check if order is not too risky (according to our risk percentage of the balance)
   if(is_order_high_risk(order)) return;
   
   // send the order
   MqlTradeResult result;
   OrderSend(order,result);
   if(result.retcode==10009 || result.retcode==10008){ //Request is completed or order placed
      Alert("A Sell order has been successfully placed with Ticket#:",result.order,"!!");
   }else{
      Alert("The Sell order request could not be completed -error:",GetLastError());
      ResetLastError();
      return;
   }   
}


bool open_position_exists(){
   return PositionSelect(_Symbol);
}


bool is_new_bar(){
   static datetime old_time;
   datetime new_time[1];
   
   // copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,new_time);
   if(copied>0){ // ok, the data has been copied successfully
      if(old_time!=new_time[0]){ // if old time isn't equal to new bar time
         if(MQL5InfoInteger(MQL5_DEBUGGING)) Print("We have new bar here ",new_time[0]," old time was ",old_time);
         old_time=new_time[0];            // saving bar time
         return true;
      }
   }else{
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
   }
   return false;
}

bool is_session_time_allowed(){
   datetime   _start = StringToTime(session_start_time);
   datetime   _finish = StringToTime(session_end_time);
   datetime _currentservertime = TimeCurrent();
   return _currentservertime>=_start && _currentservertime<=_finish;
}


MarketTrendType check_market_trend(){
   MqlRates mrate[];
   double ma1_val[];
   double ma2_val[];
   double rsi_val[];
   ArraySetAsSeries(mrate, true);
   ArraySetAsSeries(ma1_val, true);
   ArraySetAsSeries(ma2_val, true);
   ArraySetAsSeries(rsi_val, true);
   int nbars = 4;
   
   if(CopyRates(_Symbol,_Period,0,nbars,mrate)<0){  // Get the details of the last 3 bars
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return NEUTRAL;
   }
   if(CopyBuffer(ma1_handle,0,0,nbars,ma1_val)<0 || CopyBuffer(ma2_handle,0,0,nbars,ma2_val)<0){
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      ResetLastError();
      return NEUTRAL;
   }
   
   if(CopyBuffer(rsi_handle,0,0,nbars,rsi_val)<0){
      Alert("Error copying rsi indicator buffer - error:",GetLastError());
      ResetLastError();
      return NEUTRAL;
   }
   
   // check for bullish trend
   bool check = true;
   int i = 1;
   while(check && i<nbars){
      if(i<nbars-1) check&=ma1_val[i]>ma1_val[i+1];
      if(i<nbars-1) check&=ma2_val[i]>ma2_val[i+1];
      check &= ma2_val[i]>ma1_val[i];
      check &= mrate[i].close>ma2_val[i];
      i++;
   }
   if(check && rsi_val[1]>50) return BULLISH;
   
   // check for bearish trend
   check = true;
   i = 1;
   while(check && i<nbars){
      if(i<nbars-1) check&=ma1_val[i]<ma1_val[i+1];
      if(i<nbars-1) check&=ma2_val[i]<ma2_val[i+1];
      check &= ma2_val[i]<ma1_val[i];
      check &= mrate[i].close<ma2_val[i];
      i++;
   }
   if(check && rsi_val[1]<50) return BEARISH;
   
   return NEUTRAL;
}


double calc_spread(MqlRates &mrate){
   return MathAbs(mrate.open-mrate.close);
}


long calc_mean_volume(int period){
   long tick_volumes[];
   ArraySetAsSeries(tick_volumes, true);
   if(CopyTickVolume(_Symbol,_Period,0,period,tick_volumes)<0){
      Alert("Error copying tick volumes data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
   }
   
   long mean_volume=0;
   for(int i=0;i<period;i++){
      mean_volume+=tick_volumes[i];   
   }
   mean_volume/=period;
   return mean_volume;
}

bool is_volume_price_spread_divergence1(bool look_in_bullish_trend){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,_Period,0,n_candles+1,mrate)<0){  // Get the details of the last 4 bars
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
   }
   
   double mean_volume = (calc_mean_volume(21)*21-1)/20;
   double spread_volume_ratio[];
   ArrayResize(spread_volume_ratio,n_candles);
   if(look_in_bullish_trend){
      for(int i=0;i<n_candles;i++){
         double spread = calc_spread(mrate[i+1]);
         spread_volume_ratio[i] = spread / mrate[i+1].tick_volume;
         if(mrate[i+1].open - mrate[i+1].close<0) return false;
      }
      if(mrate[1].tick_volume < mean_volume) return false;
      for(int i=0;i<n_candles-1;i++){
         if(spread_volume_ratio[i]>spread_volume_ratio[i+1]) return false;
      }
      return true;
   }else{
      for(int i=0;i<n_candles;i++){
         double spread = calc_spread(mrate[i+1]);
         spread_volume_ratio[i] = spread / mrate[i+1].tick_volume;
         if(mrate[i+1].close - mrate[i+1].open<0) return false;
      }
      if(mrate[1].tick_volume < mean_volume) return false;
      for(int i=0;i<n_candles-1;i++){
         if(spread_volume_ratio[i]>spread_volume_ratio[i+1]) return false;
      }
      return true;
   }
   return false;
}

bool is_volume_price_spread_divergence(bool look_in_bullish_trend){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,_Period,0,n_candles+1,mrate)<0){  // Get the details of the last 4 bars
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
   }
   
   double mean_volume = (calc_mean_volume(21)*21-1)/20;
   double score=0;   
   for(int i=1;i<=n_candles;i++){
      if(look_in_bullish_trend){
            score += mrate[i].open-mrate[i].close<0 ? -1 : +1;  // green candle should not exist
      }else{
            score += mrate[i].open-mrate[i].close>0 ? -1 : +1;  // red candle should not exist
      }
      score += mrate[i].tick_volume<mean_volume ? -1 : +1;  //  tick volume should be higher than mean volume
      if(i==n_candles) break;
      score += calc_spread(mrate[i])>calc_spread(mrate[i+1]) ? -1 : +1;  // new candle should have lower spread than the prev candle
      score += mrate[i].tick_volume<mrate[i+1].tick_volume ? -1 : +1;  // new candle should have higher tick volume than the prev candle
   }
   double total_score = n_candles*4-2;
   if(score/(total_score)>=0.8){
      return true;
   }else{
      return false;
   }
}


MqlTradeRequest prepare_order(ENUM_ORDER_TYPE ordertype){
   MqlTradeRequest order;
   MqlTick latest_price;
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   ZeroMemory(order);
   
   if(!SymbolInfoTick(_Symbol,latest_price))
   {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return order;
   }    
   if(CopyRates(_Symbol,_Period,0,2,mrate)<0){  // Get the details of the last 2 bars
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
   }
   
   order.action=TRADE_ACTION_DEAL;                                  // immediate order execution
   order.symbol = _Symbol;                                          // currency pair
   order.volume = lot_size;                                              // number of lots to trade
   order.magic = magic_number;                                          // Order Magic Number
   order.type_filling = ORDER_FILLING_FOK;                          // Order execution type
   order.deviation=1;                                             // Deviation from current price
   
   if(ordertype==ORDER_TYPE_BUY){
      order.price = NormalizeDouble(latest_price.ask,_Digits);
      order.sl = NormalizeDouble(mrate[1].low-sl,_Digits);
      order.tp = NormalizeDouble(latest_price.ask + tp,_Digits);             
      order.type= ORDER_TYPE_BUY;         
   }else if(ordertype==ORDER_TYPE_SELL){
      order.price = NormalizeDouble(latest_price.bid,_Digits);
      order.sl = NormalizeDouble(mrate[1].high+sl,_Digits);
      order.tp = NormalizeDouble(latest_price.bid - tp,_Digits);                
      order.type= ORDER_TYPE_SELL;
   }
   return order;
}

bool is_order_high_risk(MqlTradeRequest& order){
   return false;
}


