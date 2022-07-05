/*
------------------------------------------------------------
EA made by hamid alavi.


Strategy:
   1- use 200 and 21 MAs.
   2- if 200EMA is going down and 21 MA is below it and price is below both of them, only open sell positions.
   3- if 200EMA is going up and 21 MA is above it and price is above both of them, only open buy positions.
   4- check if the incoming tick is the begin of the new bar. if so, continue.
   5- check if the previous bar is an engulfing candle. if so, continue.
      what is an engulfing candle? it is a candle that its body completely overlaps or engulfs the body of the previous day's candlestick.
   6- open a position at the close price of the engulfing candle.
   7- set SL at end of the candle's wick. check if the loss is less than 1% of balance. if so, continue.
   8- set TP according to the r/R ratio.

TODO:
   engulfing candle must have no wick (or very small)
   engulfing candle's body must be twice(variable) the size of the prev. candle
   consider price spread
-------------------------------------------------------------
*/

#property description "Engulfing candle scalper"
#include "mytools.mqh"

input int ma1_period = 200;  // MA1 period.
input int ma2_period = 21;  // MA2 period.
input double lot_size = 0.01;  // Lot Size.
input double risk_percent = 1;  // risk as a percentage of balance.
input float tp_ratio = 2;  // reward/risk ratio.

int magic_number=12345;
int ma1_handle;
int ma2_handle;

enum MarketTrendType{
   NEUTRAL=0,
   BULLISH=1,
   BEARISH=2
};

int OnInit(void)
{
   ma1_handle=iMA(_Symbol,_Period,ma1_period,0,MODE_EMA,PRICE_CLOSE);
   ma2_handle=iMA(_Symbol,_Period,ma2_period,0,MODE_EMA,PRICE_CLOSE);
   if(ma1_handle<0 || ma2_handle<0)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(ma1_handle);
   IndicatorRelease(ma2_handle);
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
     
   // check the market trend
   MarketTrendType market_trend = check_market_trend();
   if(market_trend==NEUTRAL) return;
   
   // check if there is an engulfing candle
   if(!is_engulfing_candle(market_trend==BULLISH)) return;
   
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


MarketTrendType check_market_trend(){
   MqlRates mrate[];
   double ma1_val[];
   double ma2_val[];
   ArraySetAsSeries(mrate, true);
   ArraySetAsSeries(ma1_val, true);
   ArraySetAsSeries(ma2_val, true);
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
   if(check) return BULLISH;
   
   // check for bearish trend
   check = true;
   i = 1;
   while(check && i<nbars){
      if(i<nbars-1) check&=ma1_val[i]<ma1_val[i+1];
      if(i<nbars-1) check&=ma2_val[i]<ma2_val[i+1];
      check &= ma2_val[i]<ma1_val[i];
      //check &= mrate[i].close<ma2_val[i];
      i++;
   }
   if(check) return BEARISH;
   
   return NEUTRAL;
}


bool is_engulfing_candle(bool look_for_bullish_candle){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   int nbars = 3;
   if(CopyRates(_Symbol,_Period,0,nbars,mrate)<0){  // Get the details of the last 3 bars
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
   }
   if(look_for_bullish_candle){
      if(mrate[1].close>mrate[1].open && mrate[2].close<mrate[2].open && mrate[1].close>mrate[2].open) return true;
   }else{
      if(mrate[1].close<mrate[1].open && mrate[2].close>mrate[2].open && mrate[1].close<mrate[2].open) return true;
   }
   return false;
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
      order.sl = NormalizeDouble(mrate[1].low,_Digits);
      order.tp = NormalizeDouble(latest_price.ask + tp_ratio*(latest_price.ask-mrate[1].low),_Digits);             
      order.type= ORDER_TYPE_BUY;         
   }else if(ordertype==ORDER_TYPE_SELL){
      order.price = NormalizeDouble(latest_price.bid,_Digits);
      order.sl = NormalizeDouble(mrate[1].high,_Digits);
      order.tp = NormalizeDouble(latest_price.bid - tp_ratio*(mrate[1].high-latest_price.bid),_Digits);                
      order.type= ORDER_TYPE_SELL;
   }
   return order;
}

bool is_order_high_risk(MqlTradeRequest& order){
   return false;
}


