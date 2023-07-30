/*

this EA tries to find two lower lows and two lower highs for sell positions.
also two higher lows and two higher highs for buy position.
kind of a trading inside a channel.
entry on fibonacci retracement levels
sl on last swing
tp based on reward/risk ratio

*/
#include <../Experts/mq5ea/mytools.mqh>

input group "Time settings"
input bool use_chart_timeframe = false;
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_H1;
input bool trade_only_in_session_time = false;  // entries only in specific session time of the day
input double session_start_hour = 9.0;      // session start hour (server time)
input double session_end_hour = 19.0;    // session end hour (server time)    

input group "Peak and trend detection"
input int NCandlesSearch = 200;
input int NCandlesPeak = 6;

input group "Money Management"
input double risk = 10;  // risk usd per trade
input int sl_offset_percent = 10;
input double Rr = 4.5;  // reward/risk ratio

input group "Breakeven & Riskfree & TSL"
input double breakeven_trigger_as_sl_ratio = 0;
input double riskfree_trigger_as_tp_ratio = 0;
input double tsl_offset_as_tp_ratio = 0;

input group "Fibonacci levels"
input double fib1 = 0.24;
input double fib2 = 0.57;
input int fib1lot = 1;
input int fib2lot = 1;

int Magic = 110;
double fiblevels[2];
double lotlevels[2];
CTrade trade;
ENUM_TIMEFRAMES tf;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_chart_timeframe) tf = _Period;
   else tf = convert_tf(custom_timeframe);
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
      
      if(breakeven_trigger_as_sl_ratio>0){
         int npos = ArraySize(pos_tickets);
         for(int ipos=0;ipos<npos;ipos++){
            PositionSelectByTicket(pos_tickets[ipos]);
            ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
            double curr_sl = PositionGetDouble(POSITION_SL);
            double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double curr_tp = PositionGetDouble(POSITION_TP);
            if(pos_type==POSITION_TYPE_BUY && curr_sl<open_price && curr_tp>open_price && curr_price<open_price-(open_price-curr_sl)*breakeven_trigger_as_sl_ratio){
               trade.PositionModify(pos_tickets[ipos], curr_sl, open_price);
            }else if(pos_type==POSITION_TYPE_SELL && curr_sl>open_price && curr_tp<open_price && curr_price>open_price-(open_price-curr_sl)*breakeven_trigger_as_sl_ratio){
               trade.PositionModify(pos_tickets[ipos], curr_sl, open_price);
            }   
         }
      }   
      
      if(riskfree_trigger_as_tp_ratio>0){
         int npos = ArraySize(pos_tickets);
         for(int ipos=0;ipos<npos;ipos++){
            PositionSelectByTicket(pos_tickets[ipos]);
            ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
            double curr_sl = PositionGetDouble(POSITION_SL);
            double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double curr_tp = PositionGetDouble(POSITION_TP);
            if(pos_type==POSITION_TYPE_BUY && curr_tp>open_price && curr_price>open_price+(curr_tp-open_price)*riskfree_trigger_as_tp_ratio){
               if(curr_sl<open_price) trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
               if(tsl_offset_as_tp_ratio>0) TrailingStoploss(trade, pos_tickets[ipos], (curr_tp-open_price)*tsl_offset_as_tp_ratio/_Point);
            }else if(pos_type==POSITION_TYPE_SELL && curr_tp<open_price && curr_price<open_price+(curr_tp-open_price)*riskfree_trigger_as_tp_ratio){
               if(curr_sl>open_price) trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
               if(tsl_offset_as_tp_ratio>0) TrailingStoploss(trade, pos_tickets[ipos], (open_price-curr_tp)*tsl_offset_as_tp_ratio/_Point);
            }   
         }
      }
   
      return;
   }
   
   if(!IsNewCandle(tf)) return;   
 
   PeakProperties peaks[];
   DetectPeaks(peaks, tf, 1, NCandlesSearch, NCandlesPeak, true);
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
   
   ENUM_MARKET_TREND_TYPE market_trend = DetectPeaksTrend(tf, 1, NCandlesSearch, NCandlesPeak, true);
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)){
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
   }
      
   DeleteAllOrders(trade);   
   
   if(market_trend==MARKET_TREND_NEUTRAL) return;
   if(!is_session_time_allowed_double(session_start_hour, session_end_hour) && trade_only_in_session_time) return;
   
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
      double sl = h1 + (h1-l1)*sl_offset_percent/100;
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
      double sl = l1 - (h1-l1)*sl_offset_percent/100;
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