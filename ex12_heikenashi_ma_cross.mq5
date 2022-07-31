#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES slow_tf = PERIOD_H3;
input ENUM_TIMEFRAMES fast_tf = PERIOD_H1;
//input int slow_tf_shift = 0;
//input int fast_tf_shift = 0;
input int ma_slow_period = 30;
input int ma_fast_period = 1;
input int ma_slow_shift = 0;
input int ma_fast_shift = 0;
input double lot_size = 0.1;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input int Magic = 120;

CTrade trade;
int slow_heiken_ashi_handle, fast_heiken_ashi_handle;

#define HA_MA_BUFFER 5

int OnInit()
{  
   trade.SetExpertMagicNumber(Magic);
   slow_heiken_ashi_handle = iCustom(_Symbol, slow_tf, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema.ex5", MODE_EMA, ma_slow_period);
   fast_heiken_ashi_handle = iCustom(_Symbol, fast_tf, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema.ex5", MODE_EMA, ma_fast_period);
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(slow_heiken_ashi_handle);
   IndicatorRelease(fast_heiken_ashi_handle);
}

void OnTick()
{  
   ulong pos_tickets[];
   GetMyPositionsTickets(trade.RequestMagic(), pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos-1;ipos++){
      trade.PositionClose(pos_tickets[ipos]);
   }
   if(!IsNewCandle(fast_tf)) return;   
   double slow_ma[2], fast_ma[2];
   CopyBuffer(slow_heiken_ashi_handle, HA_MA_BUFFER, 1+ma_slow_shift, 2, slow_ma);
   CopyBuffer(fast_heiken_ashi_handle, HA_MA_BUFFER, 1+ma_fast_shift, 2, fast_ma);
   ArrayReverse(slow_ma, 0, WHOLE_ARRAY);
   ArrayReverse(fast_ma, 0, WHOLE_ARRAY);
   if(fast_ma[0]>slow_ma[0] && fast_ma[1]<slow_ma[1] && fast_ma[0]>fast_ma[1]){ // up cross
      CloseAllPositions(trade);
      double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(lot_size, _Symbol, ask_price);
   }else if(fast_ma[0]<slow_ma[0] && fast_ma[1]>slow_ma[1] && fast_ma[0]<fast_ma[1]){ // down cross
      CloseAllPositions(trade);
      double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(lot_size, _Symbol, bid_price);      
   }
}

void OnTrade()
{

}
