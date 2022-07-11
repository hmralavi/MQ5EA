/*

TODO: 
   1- open positions based on the dominant trend (bullish/bearish).
*/
#include <../Experts/mq5ea/mytools.mqh>

input int NCandlesHistory = 500;
input int NCandlesPeak = 5;
input double LotSize = 0.01;
input int SlPoints = 100;
input double RRatio = 2;
input bool TSL_Enabled = false;  // Trailing stoploss enabled
input int Magic = 100;

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
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   if(npos>0){
      DeleteAllOrders(trade);
      if(TSL_Enabled){
         for(int i=0; i<npos; i++) TrailingStoploss(trade, pos_tickets[i], SlPoints, SlPoints);
      }
      return;
   }
   if(IsNewCandle()){
      double peak_levels[];
      datetime peak_times[];
      bool peak_tops[];
      DetectPeaks(peak_levels, peak_times, peak_tops, 1, NCandlesHistory, NCandlesPeak);
      ObjectsDeleteAll(0);
      PlotPeaks(peak_levels, peak_times, peak_tops);
      
      DeleteAllOrders(trade);
      
      double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int npeaks = ArraySize(peak_levels);
      bool buyset = false;
      bool sellset = false;
      for(uint i=0; i<npeaks; i++){
         if(peak_tops[i] && (bid_price < peak_levels[i]) && !sellset){
            double sl = peak_levels[i] + SlPoints * _Point;
            double tp = peak_levels[i] - RRatio * SlPoints * _Point;
            trade.SellLimit(LotSize, peak_levels[i], _Symbol, sl, tp);
            sellset = true;
         }else if(!peak_tops[i] && (ask_price > peak_levels[i]) && !buyset){
            double sl = peak_levels[i] - SlPoints * _Point;
            double tp = peak_levels[i] + RRatio * SlPoints * _Point;
            trade.BuyLimit(LotSize, peak_levels[i], _Symbol, sl, tp);
            buyset = true;         
         }
         if(sellset && buyset) break;
      }
   
   }   
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   
}
  

