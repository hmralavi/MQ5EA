/*
------------------------------------------------------------
Bollinger bands day trading EA
Made by hamid alavi.

https://tradingstrategyguides.com/bollinger-bands-bounce-trading-strategy/#How_To_Use_Bollinger_Band_Indicator
Strategy:
1H or 4H timeframe
bb 20,close,2  (9,close,2 for 5m timeframe)
rsi 14
detect uptrend(downtrend)
wait for the price to touch the bottom(upper) band. (If it is any more than 5 pips away then I would not consider this validated)
rsi should be between 30-50 (50-70) and be rising (falling)
make an entry when you see some bullish (bearish) candles (engulfing, 80% big body, etc.)
stop loss 30-50 pip
take profit options: 2*SL, bollinger upper(bottom) band, half on 1std bb band and half on 2std band.

   
-------------------------------------------------------------
*/

#property description "Bollinger bands + RSI day trading EA"


int OnInit(void)
{
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{
   
}