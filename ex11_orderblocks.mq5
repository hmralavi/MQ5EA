/*

TODO:
DONE--> important: currently, we try to find the orderblock as a peak right after the broken peak. but in fact, it should be the peak right before the breaking candle.
DONE--> trade only when the major orderblock is only touched two times or less
DONE--> find order blocks based on imbalancing zone/candle.
DONE--> trade in market's direction
ignore double orderblock confirmation. but use candlestick confirmation.
set higher sl but on the other hand, place tp on open price if we have reached an specific amount of loss. additionally, open a position in the opposite direction.
should work on stoploss level more
close half of the position on specific profit



*/
#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES MinorTF = PERIOD_M5;  // timeframe for orderblocks
input ENUM_TIMEFRAMES MajorTF = PERIOD_H1;  // Timeframe for market's trend
input int NCandlesHistory = 500;  // n candles for history
input int NCandlesPeak = 6;  // how many candles to form a peak?
input bool ObMustHaveFVG = true;  // orderblock must be followed by fvg
input double LotSize = 0.1;
input int SlPoints = 50;
input double RRatio = 10;
input bool TSL_Enabled = true;  // Trailing stoploss enabled
input bool TradeInMarketDirection = false;  // Trade in market's direction
input bool trade_only_in_session_time = false;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input int Magic = 110;

CTrade trade;
double _slpoints;
OrderBlockProperties minor_obs[]; 
PeakProperties minor_peaks[];
ENUM_MARKET_TREND_TYPE market_trend = MARKET_TREND_NEUTRAL;
OrderBlockProperties touched_ob;
bool ready_for_buy = false;
bool ready_for_sell = false;
int npassed_candles = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0);
}

void OnTick()
{  
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   if(npos>0){
      if(TSL_Enabled){
         for(int i=0; i<npos; i++) TrailingStoploss(trade, pos_tickets[i], _slpoints, 2*_slpoints);
      }
      return;
   }
   
   if(!is_session_time_allowed(session_start_time, session_end_time) && trade_only_in_session_time) return;
   
   double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double touched_ob_low;
   double touched_ob_high;
   GetOrderBlockZone(touched_ob, touched_ob_low, touched_ob_high);  
   if(npassed_candles>5){
      ready_for_buy = false;
      ready_for_sell = false;
      npassed_candles = 0;
   }      
   
   if(ready_for_buy){
      if(!IsNewCandle(MinorTF)) return;
      npassed_candles++;
      if(!CandleConfirmation(true)) return;
      double sl = touched_ob_low - SlPoints * _Point;
      double tp = ask_price + (ask_price-sl) * RRatio;               
      _slpoints = (bid_price - sl)/_Point;   
      if(_slpoints<100) trade.Buy(LotSize, _Symbol, ask_price, sl, tp);
      ready_for_buy = false;
      npassed_candles = 0;
      return;
   }
   if(ready_for_sell){
      if(!IsNewCandle(MinorTF)) return;
      npassed_candles++;
      if(!CandleConfirmation(false)) return;
      double sl = touched_ob_high + SlPoints * _Point;
      double tp = bid_price - (sl-bid_price) * RRatio;          
      _slpoints = (sl - ask_price)/_Point;     
      if(_slpoints<100) trade.Sell(LotSize, _Symbol, bid_price, sl, tp); 
      ready_for_sell = false;
      npassed_candles = 0;
      return;  
   }
   
   int nminors = ArraySize(minor_obs);
   for(int iminor=0;iminor<nminors;iminor++){
      if(minor_obs[iminor].isBroken) continue; // check if the minor zone is broken
      if(ArraySize(minor_obs[iminor].touching_candles)>1) continue;  // the zone should not be touched more than once.         
      double ob_minor_low;
      double ob_minor_high;
      GetOrderBlockZone(minor_obs[iminor], ob_minor_low, ob_minor_high);       
      if(bid_price<=ob_minor_high && bid_price>=ob_minor_low){         
         if(minor_obs[iminor].isDemandZone && (market_trend==MARKET_TREND_BULLISH || !TradeInMarketDirection)){ // open buy position
            ready_for_buy = true;
            touched_ob = minor_obs[iminor];
            break;
         }else if(!minor_obs[iminor].isDemandZone && (market_trend==MARKET_TREND_BEARISH || !TradeInMarketDirection)){  // open sell position
            ready_for_sell = true;
            touched_ob = minor_obs[iminor];
            break;
         }               
      }
   }   

   if(!IsNewCandle(MinorTF)) return;
   
   DetectPeaks(minor_peaks, MinorTF, 0, NCandlesHistory, NCandlesPeak);

   DetectOrderBlocks(minor_obs, MinorTF, 0, NCandlesHistory, NCandlesPeak, ObMustHaveFVG);
   
   if(TradeInMarketDirection){
      market_trend = DetectPeaksTrend(MajorTF, 1, NCandlesHistory, NCandlesPeak); 
      switch(market_trend){
      case MARKET_TREND_BULLISH:
         Comment("Market Bullish");
         break;
      case MARKET_TREND_BEARISH:
         Comment("Market Bearish");
         break;
      case MARKET_TREND_NEUTRAL:
         Comment("Market Neutral");
         break;
      }
   }  
   
   ObjectsDeleteAll(0);   
   PlotPeaks(minor_peaks, 1);
   PlotOrderBlocks(minor_obs, "minor", STYLE_SOLID, 1, false, -1);
   ChartRedraw(0);
   
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   
}

bool CandleConfirmation(bool buy_position){
   int n = 2;
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,MinorTF,1,n,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
   }
   if(buy_position && mrate[0].close>MathMax(mrate[1].close,mrate[1].open)) return true;
   if(!buy_position && mrate[0].close<MathMin(mrate[1].close,mrate[1].open)) return true;
   return false;
}
  

