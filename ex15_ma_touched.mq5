/*
MA touched EA

Strategy:
   1- Consider two MAs; a fast (e.g 10 candle) and a slow (e.g. 30 candle).
   2- if price> fast > slow ==> uptrend ==> only buy
      else downtrend ==> only sell
   3- on a new candle, place an order on the fast MA
   4- set SL on the on the other side of the slow MA by an offset
   5- options: TSL, session time, risk per trade, 
   
 TODO:
   1- set sl by on offset from the fast MA.
      if sl hits, open a reverse position to reach to the slow MA
*/

int OnInit()
{

   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{


}

void OnTick()
{


}

