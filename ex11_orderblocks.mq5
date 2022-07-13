/*

TODO: 
must detect orderblocks more accurately

*/
#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES MinorTF = PERIOD_M5;
input ENUM_TIMEFRAMES MajorTF = PERIOD_H1;
input int NCandlesMinorTF = 288;
input int NCandlesMajorTF = 168;
input int NCandlesPeak = 6;
input double LotSize = 0.1;
input int SlPoints = 50;
input double RRatio = 10;
input bool TSL_Enabled = true;  // Trailing stoploss enabled
input int Magic = 110;

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
   if(!IsNewCandle(MinorTF)) return;
   
   OrderBlockProperties major_obs[]; 
   DetectOrderBlocks(major_obs, MajorTF, 0, NCandlesMajorTF, NCandlesPeak);

   OrderBlockProperties minor_obs[]; 
   DetectOrderBlocks(minor_obs, MinorTF, 0, NCandlesMinorTF, NCandlesPeak);
   
   //ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(MajorTF, 1, NCandlesMajorTF, NCandlesPeak);
   //if(market_trend==MARKET_TREND_NEUTRAL) return;

   
   //ObjectsDeleteAll(0);
   //ChartRedraw(0);
   //Sleep(100);
   //PlotOrderBlocks(major_obs, "major", STYLE_SOLID, false);
   //PlotOrderBlocks(minor_obs, "minor", STYLE_DOT, false);
   //return;

   double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int nmajors = ArraySize(major_obs);
   int nminors = ArraySize(minor_obs);
   bool trade_allowed = true;
   for(int imajor=0;imajor<nmajors;imajor++){
      if(!trade_allowed) break;
      if(major_obs[imajor].breaking_candle.low>0) continue; // check if the major zone is broken
      if(bid_price<=major_obs[imajor].main_candle.high && bid_price>=major_obs[imajor].main_candle.low){
         for(int iminor=0;iminor<nminors;iminor++){
            if(minor_obs[iminor].isDemandZone != major_obs[imajor].isDemandZone) continue; // we want the minor and major zones to be of the same type demand/supply.
            if(minor_obs[iminor].breaking_candle.low>0) continue; // check if the minor zone is broken
            if(bid_price<=minor_obs[iminor].main_candle.high && bid_price>=minor_obs[iminor].main_candle.low){
               if(minor_obs[iminor].isDemandZone){ // open buy position
                  double sl = minor_obs[iminor].main_candle.low - SlPoints * _Point;
                  double tp = ask_price + RRatio * SlPoints * _Point;
                  trade.Buy(LotSize, _Symbol, ask_price, sl, tp);
               }else if(!minor_obs[iminor].isDemandZone){  // open sell position
                  double sl = minor_obs[iminor].main_candle.high + SlPoints * _Point;
                  double tp = bid_price - RRatio * SlPoints * _Point;
                  trade.Sell(LotSize, _Symbol, bid_price, sl, tp);
               }
               trade_allowed = false;
               ObjectsDeleteAll(0,-1,-1);
               ChartRedraw(0);
               Sleep(100);
               OrderBlockProperties majo[1];
               OrderBlockProperties mino[1];
               majo[0] = major_obs[imajor];
               mino[0] = minor_obs[iminor];
               PlotOrderBlocks(majo, "major", STYLE_SOLID, false);
               PlotOrderBlocks(mino, "minor", STYLE_DOT, false);
               break;
            }
         }
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   
}
  

