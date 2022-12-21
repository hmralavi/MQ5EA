/*
Fake shadow EA

Strategy:
   1- wait for a new candle
   2- get the last two closed candles
   3- if the older candle is a red(green) one and has a long up(down) shadow
   4- and if the newer candle is a green(red) full body candle
   5- enter buy(sell) position
*/

#include <../Experts/mq5ea/mytools.mqh>

input bool use_chart_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M2;
input double sl_offset_points = 30;  // sl points 
input double Rr_ratio = 3; // reward/risk ratio
input double lot = 0.01;  // lot size
input double shadow_ratio = 0.55;
input double body_ratio = 0.75;

input group "Trailing stoploss"
input bool trailing_stoploss = true;
input double tsl_offset_points = 30;
input double tsl_trigger_points = 30;

input int Magic = 180;  // EA's magic number

CTrade trade;
ENUM_TIMEFRAMES tf;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_chart_timeframe) tf = _Period;
   else tf = costume_timeframe;
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{

}

void OnTick()
{
   if(!IsNewCandle(tf)) return;
      
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   if(npos>0){
      if(trailing_stoploss){
         for(int ipos=0;ipos<npos;ipos++){
            TrailingStoploss(trade, pos_tickets[ipos], tsl_offset_points, tsl_trigger_points);         
         }
      }
      return;
   }
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, tf, 0, 3, rates);
   double ask, bid, sl, tp;
   if(rates[2].close<rates[2].open && (rates[2].high-rates[2].open)/(rates[2].high-rates[2].low)>shadow_ratio && rates[1].close>rates[1].open && (rates[1].close-rates[1].open)/(rates[1].high-rates[1].low)>body_ratio){   // buy position
      ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = rates[1].low - sl_offset_points*_Point;
      tp = ask + (ask-sl)*Rr_ratio;
      trade.Buy(lot, _Symbol, ask, sl, tp);
      
   }else if(rates[2].close>rates[2].open && (rates[2].open-rates[2].low)/(rates[2].high-rates[2].low)>shadow_ratio && rates[1].close<rates[1].open && (rates[1].open-rates[1].close)/(rates[1].high-rates[1].low)>body_ratio){   // sell position{
      bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = rates[1].high + sl_offset_points*_Point;
      tp = bid - (sl-bid)*Rr_ratio;
      trade.Sell(lot, _Symbol, bid, sl, tp);   
   
   }
  

}

