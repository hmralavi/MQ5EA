/*

TODO: 

*/
#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES MainTimeFrame = PERIOD_M15;
input ENUM_TIMEFRAMES TrendTimeFrame = PERIOD_H1;
input int NCandlesHistory = 500;
input int NCandlesPeak = 6;
input double LotSize = 0.1;
input int SlPoints = 300;
input double RRatio = 4;
input bool TSL_Enabled = true;  // Trailing stoploss enabled
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
         for(int i=0; i<npos; i++) TrailingStoploss(trade, pos_tickets[i], SlPoints, 2*SlPoints);
      }
      return;
   }
   if(IsNewCandle(MainTimeFrame)){
      double peak_levels[];
      datetime peak_times[];
      int peak_shifts[];
      bool peak_tops[];
      DetectPeaks(peak_levels, peak_times, peak_shifts, peak_tops, MainTimeFrame, 1, NCandlesHistory, NCandlesPeak);
      ObjectsDeleteAll(0);
      //PlotPeaks(peak_levels, peak_times, peak_tops);
      
      DeleteAllOrders(trade);
      
      ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(TrendTimeFrame, 1, NCandlesHistory, NCandlesPeak);
      if(market_trend==MARKET_TREND_NEUTRAL) return;
      
      double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int npeaks = ArraySize(peak_levels);
      
      for(uint i=0; i<npeaks; i++){
         if(peak_tops[i] && (bid_price < peak_levels[i]) && market_trend==MARKET_TREND_BEARISH){
            double sl = peak_levels[i] + SlPoints * _Point;
            double tp = peak_levels[i] - RRatio * SlPoints * _Point;
            trade.SellLimit(LotSize, peak_levels[i], _Symbol, sl, tp);
            break;
         }else if(!peak_tops[i] && (ask_price > peak_levels[i]) && market_trend==MARKET_TREND_BULLISH){
            double sl = peak_levels[i] - SlPoints * _Point;
            double tp = peak_levels[i] + RRatio * SlPoints * _Point;
            trade.BuyLimit(LotSize, peak_levels[i], _Symbol, sl, tp);
            break;       
         }
      }  
   }   
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   
}
  

