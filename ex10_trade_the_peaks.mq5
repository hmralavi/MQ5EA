/*

TODO: 
   1- open positions based on the dominant trend (bullish/bearish).
*/
#include <../Experts/mq5ea/mytools.mqh>

input uint NCandles = 5;
input double LotSize = 0.01;
input uint SlPoints = 100;
input bool TSL = false;  // Trailing stoploss
input uint Magic = 100;

CTrade trade;

int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   
  }

void OnTick()
  {
   /*
   openposition exist --> tsl
   
   pendingorder exist --> return
   
   isnewcandle ---> detect peaks
   
   place order
   
   if(NPositions(Magic)==0){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl;
      double tp;
      bool buy = rand()/32767.0 < 0.5;
      if(buy) {
         tp = ask + 1 * SlPoints * _Point;
         sl = bid - SlPoints * _Point;     
      }else{
         tp = bid - 1 * SlPoints * _Point;
         sl = ask + SlPoints * _Point;     
      }
      ask = NormalizeDouble(ask,_Digits);
      bid = NormalizeDouble(bid,_Digits);
      tp = NormalizeDouble(tp,_Digits);
      sl = NormalizeDouble(sl,_Digits);
      if(buy){
         trade.Buy(LotSize,_Symbol,ask,sl,tp);
      }else{
         trade.Sell(LotSize,_Symbol,bid,sl,tp);
      }
   }else{
      ulong posticket = PositionGetTicket(0);
      //TrailingStoploss(trade, posticket, SlPoints, SlPoints);
   }
   */
  }

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   
  }
  

