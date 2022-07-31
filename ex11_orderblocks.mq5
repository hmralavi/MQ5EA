/*

TODO:
DONE--> important: currently, we try to find the orderblock as a peak right after the broken peak. but in fact, it should be the peak right before the breaking candle.
DONE--> trade only when the major orderblock is only touched two times or less
DONE--> find order blocks based on imbalancing zone/candle.
DONE--> trade in market's direction
set higher sl but on the other hand, place to on open price if we have reached an specific amount of loss. additionally, open a position in the opposite direction.
should work on stoploss level more
close half of the position on specific profit



*/
#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES MinorTF = PERIOD_M5;
input ENUM_TIMEFRAMES MajorTF = PERIOD_H1;
input int NCandlesMinorTF = 500;
input int NCandlesMajorTF = 720;
input int NCandlesPeak = 6;
input bool ObMustHaveFVG = false;  // orderblock must be followed by fvg
input int NMaxMinorOBToShow = -1;
input int NMaxMajorOBToShow = -1;
input double LotSize = 0.1;
input int SlPoints = 50;
input double RRatio = 10;
input bool TSL_Enabled = true;  // Trailing stoploss enabled
input bool TradeInMarketDirection = false;  // Trade in market's direction
input ENUM_TIMEFRAMES MarketTrendTF = PERIOD_H1;
input int Magic = 110;

CTrade trade;
double _slpoints;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   ObjectsDeleteAll(0);
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
         for(int i=0; i<npos; i++) TrailingStoploss(trade, pos_tickets[i], 2*_slpoints, 2*_slpoints);
      }
      return;
   }
   if(!IsNewCandle(MinorTF)) return;
   
   PeakProperties major_peaks[];
   DetectPeaks(major_peaks, MajorTF, 0, NCandlesMajorTF, NCandlesPeak);
   
   PeakProperties minor_peaks[];
   DetectPeaks(minor_peaks, MinorTF, 0, NCandlesMinorTF, NCandlesPeak);
   
   OrderBlockProperties major_obs[]; 
   DetectOrderBlocks(major_obs, MajorTF, 0, NCandlesMajorTF, NCandlesPeak, ObMustHaveFVG);

   OrderBlockProperties minor_obs[]; 
   DetectOrderBlocks(minor_obs, MinorTF, 0, NCandlesMinorTF, NCandlesPeak, ObMustHaveFVG);
   
   ObjectsDeleteAll(0);
   ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(MarketTrendTF, 1, NCandlesMajorTF, NCandlesPeak);   
   
   PlotPeaks(major_peaks, 3);
   PlotPeaks(minor_peaks, 1);
   PlotOrderBlocks(major_obs, "major", STYLE_SOLID, 2, false, NMaxMajorOBToShow);
   PlotOrderBlocks(minor_obs, "minor", STYLE_SOLID, 1, false, NMaxMinorOBToShow);
   ChartRedraw(0);
   Sleep(100);
   //return;
   
   if(market_trend==MARKET_TREND_NEUTRAL && TradeInMarketDirection) return;

   double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int nmajors = ArraySize(major_obs);
   int nminors = ArraySize(minor_obs);
   bool trade_allowed = true;
   for(int imajor=0;imajor<nmajors;imajor++){
      if(!trade_allowed) break;
      if(major_obs[imajor].isBroken) continue; // check if the major zone is broken
      if(ArraySize(major_obs[imajor].touching_candles)>2) continue; // check if the major zone is touched more than two times
      double ob_major_low;
      double ob_major_high;
      GetOrderBlockZone(major_obs[imajor], ob_major_low, ob_major_high);
      if(bid_price<=ob_major_high && bid_price>=ob_major_low){
         for(int iminor=0;iminor<nminors;iminor++){
            if(minor_obs[iminor].isDemandZone != major_obs[imajor].isDemandZone) continue; // we want the minor and major zones to be of the same type demand/supply.
            if(minor_obs[iminor].isBroken) continue; // check if the minor zone is broken
            double ob_minor_low;
            double ob_minor_high;
            GetOrderBlockZone(minor_obs[iminor], ob_minor_low, ob_minor_high);           
            if(bid_price<=ob_minor_high && bid_price>=ob_minor_low){
               if(minor_obs[iminor].isDemandZone && (market_trend==MARKET_TREND_BULLISH || !TradeInMarketDirection)){ // open buy position
                  double sl = ob_minor_low - SlPoints * _Point;
                  double tp = ask_price + RRatio * SlPoints * _Point;               
                  _slpoints = (bid_price - sl)/_Point;   
                  trade.Buy(LotSize, _Symbol, ask_price, sl, tp);
                  trade_allowed = false;
               }else if(!minor_obs[iminor].isDemandZone && (market_trend==MARKET_TREND_BEARISH || !TradeInMarketDirection)){  // open sell position
                  double sl = ob_minor_high + SlPoints * _Point;
                  double tp = bid_price - RRatio * SlPoints * _Point;          
                  _slpoints = (sl - ask_price)/_Point;     
                  trade.Sell(LotSize, _Symbol, bid_price, sl, tp);
                  trade_allowed = false;
               }               
               //ObjectsDeleteAll(0,-1,-1);
               //ChartRedraw(0);
               //Sleep(100);
               //OrderBlockProperties majo[1];
               //OrderBlockProperties mino[1];
               //majo[0] = major_obs[imajor];
               //mino[0] = minor_obs[iminor];
               //PlotOrderBlocks(majo, "major", STYLE_SOLID, 3, false, NMaxMajorOBToShow);
               //PlotOrderBlocks(mino, "minor", STYLE_SOLID, 1, false, NMaxMinorOBToShow);
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
  

