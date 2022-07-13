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
      PeakProperties peaks[];
      DetectPeaks(peaks, MainTimeFrame, 1, NCandlesHistory, NCandlesPeak);
      ObjectsDeleteAll(0);
      //PlotPeaks(peak_levels, peak_times, peak_tops);
      
      DeleteAllOrders(trade);
      
      ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(TrendTimeFrame, 1, NCandlesHistory, NCandlesPeak);
      if(market_trend==MARKET_TREND_NEUTRAL) return;
      
      double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int npeaks = ArraySize(peaks);
      
      for(uint i=0; i<npeaks; i++){
         if(peaks[i].isTop && (bid_price < peaks[i].main_candle.high) && market_trend==MARKET_TREND_BEARISH){
            double sl = peaks[i].main_candle.high + SlPoints * _Point;
            double tp = peaks[i].main_candle.high - RRatio * SlPoints * _Point;
            trade.SellLimit(LotSize, peaks[i].main_candle.high, _Symbol, sl, tp);
            break;
         }else if(!peaks[i].isTop && (ask_price > peaks[i].main_candle.low) && market_trend==MARKET_TREND_BULLISH){
            double sl = peaks[i].main_candle.low - SlPoints * _Point;
            double tp = peaks[i].main_candle.low + RRatio * SlPoints * _Point;
            trade.BuyLimit(LotSize, peaks[i].main_candle.low, _Symbol, sl, tp);
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
  

