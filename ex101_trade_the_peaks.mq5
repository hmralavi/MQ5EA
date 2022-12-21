/*

this EA tries to find two lower lows and two lower highs for sell positions.
also two higher lows and two higher highs for buy position.
kind of a trading inside a channel.
entry on fibonacci retracement levels
sl on last swing
tp based on reward/risk ratio

*/
#include <../Experts/mq5ea/mytools.mqh>

input group "Peak and trend detection"
input int NCandlesSearch = 200;
input int NCandlesPeak = 6;

input group "Money Management"
input double risk = 10;  // risk usd per trade
input int sl_points_offset = 50;
input double Rr = 4.5;  // reward/risk ratio

input group "Trailing stoploss"
input bool trailing_stoploss = true;
input double tsl_offset_points = 300;
input double tsl_trigger_points = 300;

input group "Fibonacci levels"
input double fib1 = 0.24;
input double fib2 = 0.57;
input int fib1lot = 1;
input int fib2lot = 1;

int Magic = 110;
double fiblevels[2];
double lotlevels[2];
CTrade trade;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   ObjectsDeleteAll(0);
   fiblevels[0] = fib1;
   fiblevels[1] = fib2;
   lotlevels[0] = fib1lot;
   lotlevels[1] = fib2lot;
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
      if(trailing_stoploss){
         for(int ipos=0;ipos<npos;ipos++){
            TrailingStoploss(trade, pos_tickets[ipos], tsl_offset_points, tsl_trigger_points);         
         }
      }
      return;
   }
   
   if(!IsNewCandle(_Period)) return;   
 
   PeakProperties peaks[];
   DetectPeaks(peaks, _Period, 1, NCandlesSearch, NCandlesPeak, true);
   ObjectsDeleteAll(0);
   ObjectsDeleteAll(0);
   ChartRedraw(0);
   PeakProperties peaks_[4];
   peaks_[0] = peaks[0];
   peaks_[1] = peaks[1];
   peaks_[2] = peaks[2];
   peaks_[3] = peaks[3];
   PlotPeaks(peaks_);
   ChartRedraw(0);
   
   ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(_Period, 1, NCandlesSearch, NCandlesPeak, true);
   switch(market_trend) {
      case MARKET_TREND_BEARISH:
         Comment("BEARISH");
         break;
      case MARKET_TREND_BULLISH:
         Comment("BULLISH");
         break;
      default:
         Comment("NEUTRAL");
         break;
   }
      
   DeleteAllOrders(trade);   
   
   if(market_trend==MARKET_TREND_NEUTRAL) return;
   
   double h1,l1;
   if(peaks[0].isTop){
      h1 = peaks[0].main_candle.high;
      l1 = peaks[1].main_candle.low;
   }else{
      h1 = peaks[1].main_candle.high;
      l1 = peaks[0].main_candle.low;
   }
   
   double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double p[];
   ArrayResize(p, ArraySize(fiblevels));
   int nlevels = ArraySize(fiblevels);
   double meanp=0;
   double lotsum=0;
   
   if(bid_price<h1 && market_trend==MARKET_TREND_BEARISH){
      for(int i=0;i<nlevels;i++){
         lotsum += lotlevels[i];
         p[i] = -(h1-l1)*fiblevels[i] + h1;
         p[i] = NormalizeDouble(p[i], _Digits);
         meanp += lotlevels[i]*p[i];
      }
      meanp /= lotsum;
      double sl = h1 + sl_points_offset * _Point;
      double tp = meanp - Rr*(sl-meanp);
      double lot = calculate_lot_size((sl-meanp)/_Point, risk);
      for(int i=0;i<nlevels;i++){
         double lot_ = NormalizeDouble(lot*lotlevels[i]/lotsum, 2);
         trade.SellLimit(lot_, p[i], _Symbol, sl, tp);
      } 
      return;    
   }else if(bid_price>l1 && market_trend==MARKET_TREND_BULLISH){
      for(int i=0;i<nlevels;i++){
         lotsum += lotlevels[i];
         p[i] = (h1-l1)*fiblevels[i] + l1;
         p[i] = NormalizeDouble(p[i], _Digits);
         meanp += lotlevels[i]*p[i];
      }
      meanp /= lotsum;
      double sl = l1 - sl_points_offset * _Point;
      double tp = meanp + Rr*(meanp-sl);
      double lot = calculate_lot_size((meanp-sl)/_Point, risk);
      for(int i=0;i<nlevels;i++){
         double lot_ = NormalizeDouble(lot*lotlevels[i]/lotsum, 2);
         trade.BuyLimit(lot_, p[i], _Symbol, sl, tp);
      }   
      return;
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD){
      CDealInfo deal;
      deal.Ticket(trans.deal);
      HistorySelect(TimeCurrent()-PeriodSeconds(PERIOD_D1), TimeCurrent()+10);
      if(deal.Magic()==Magic && deal.Symbol()==_Symbol){
         if(deal.Entry()==DEAL_ENTRY_OUT){
            //DeleteAllOrders(trade);
            //CloseAllPositions(trade);
         }
      }
   }   
}