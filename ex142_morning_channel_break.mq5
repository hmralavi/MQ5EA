/*
ex14_morning_channel_break EA

similar to ex141
differences: 
1-the orders/positions only get place at one single price
2-daily loss limit removed
3-breaking candle's open must be inside the box

   
*/


#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>


enum ENUM_EXIT_POLICY{
   EXIT_POLICY_BREAKEVEN = 0,  // Breakeven if in loss/Instant exit if in profit
   EXIT_POLICY_INSTANT = 1  // instant exit anyway
};

input group "Time"
input bool use_chart_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M15;
input int market_open_hour = 3;
input int market_open_minute = 0;
input int market_duration_minutes = 60;
input int market_terminate_hour = 20;
input int market_terminate_minute = 0;
input double no_new_trade_timerange_ratio = 0.5;
input ENUM_MONTH trading_month=MONTH_JAN;  // trade only in this month
input int trading_day_start = 1;
input int trading_day_end = 31;
input group "Risk"
input double sl_offset_points = 50;  // sl offset points channel edge
input double risk_original = 400;  // risk usd per trade
input double Rr = 3;  // reward/risk ratio
input group "Position"
input bool instant_entry = false;
input double order_price_ratio = 0.0;  // order price ratio. 0 close to broken edge. 1 on the other side of the channel.
input bool close_only_half_size_on_tp = true;
input ENUM_EXIT_POLICY after_terminate_time_exit_policy = EXIT_POLICY_BREAKEVEN;  // how to close open positions when market_terminate time triggers?
input group "Trailing Stoploss"
input bool risk_free = false;
input bool trailing_stoploss = false;
input int atr_period = 100;
input double atr_channel_deviation = 2;
input group "Optimization criteria for prop challenge"
input bool prop_challenge_criteria_enabled = true; // Enabled?
input double prop_challenge_min_profit_usd = 800; // Min profit desired(usd);
input double prop_challenge_max_drawdown_usd = 1200;  // Max drawdown desired(usd);
input double prop_challenge_daily_loss_limit = 450;  // Max loss (usd) in one day
input double new_risk_if_prop_passed = 10; // new risk (usd) if prop challenge is passed.
input group "EA settings"
input double equity_stop_trading = 0;  // Stop trading if account equity is above this:
input string PositionComment = "";
input int Magic = 142;  // EA's magic number

CTrade trade;
ENUM_TIMEFRAMES tf;
int timezone_channel_handle, atr_handle;
double risk = risk_original;
PropChallengeCriteria prop_challenge_criteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, trading_month, Magic);

#define ZONE_UPPER_EDGE_BUFFER 0
#define ZONE_LOWER_EDGE_BUFFER 2
#define ZONE_TYPE_BUFFER 4

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_chart_timeframe) tf = _Period;
   else tf = costume_timeframe;
   timezone_channel_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\timezone_channel.ex5", market_open_hour, market_open_minute, market_duration_minutes, market_terminate_hour, market_terminate_minute, no_new_trade_timerange_ratio);
   ChartIndicatorAdd(0, 0, timezone_channel_handle);
   if(trailing_stoploss) atr_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\atr_channel.ex5", false, atr_period, atr_channel_deviation);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   IndicatorRelease(timezone_channel_handle);
   IndicatorRelease(atr_handle);
}

void OnTick()
{  
   if(equity_stop_trading>0){
      double acc_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(acc_eq>=equity_stop_trading){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   if(prop_challenge_criteria_enabled){
      prop_challenge_criteria.update();
      if(prop_challenge_criteria.is_current_period_passed() && risk>new_risk_if_prop_passed){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
      }
   }
   
   double zone_type[1];
   CopyBuffer(timezone_channel_handle, ZONE_TYPE_BUFFER, 0, 1, zone_type);
   
   if(zone_type[0]<=1){
      DeleteAllOrders(trade);
      run_exit_policy();
      return;
   }
   
   MqlDateTime current_date;
   TimeToStruct(TimeCurrent(), current_date);
   if(trading_month>0) if(current_date.mon != trading_month) return;
   if(current_date.day<trading_day_start || current_date.day>trading_day_end) return; 
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   
   if(risk_free){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         RiskFree(trade, pos_tickets[ipos]);      
      }
   }

   if(trailing_stoploss){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double tp = PositionGetDouble(POSITION_TP);  
         double tp_rr1 = MathAbs(tp-open_price)/Rr;
         double atr[1];
         CopyBuffer(atr_handle, pos_type==POSITION_TYPE_BUY?6:5, 0, 1, atr);  // buffer 5 atrhigh, buffer 6 atrlow
         TrailingStoploss(trade, pos_tickets[ipos], MathAbs(atr[0]-curr_price)/_Point, tp_rr1/_Point);         
      }
   }
   if(ArraySize(pos_tickets) + ArraySize(ord_tickets) > 0) return;  
   
   if(!IsNewCandle(tf)) return;
   
   if(prop_challenge_criteria_enabled){
      if(prop_challenge_criteria.is_current_period_passed()){
         risk = new_risk_if_prop_passed;
      }else{
         double period_prof = prop_challenge_criteria.get_current_period_profit();
         double risk_to_reach_drawdown = period_prof + prop_challenge_max_drawdown_usd;
         risk = MathMin(risk_original, risk_to_reach_drawdown);
      }
      double today_profit = prop_challenge_criteria.get_today_profit();
      if(today_profit-risk*1.01<=-prop_challenge_daily_loss_limit) return;
      if(!prop_challenge_criteria.is_current_period_drawdown_passed()) return;
   }
   
   if(zone_type[0]!=2) return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double upper_edge[1];
   double lower_edge[1];
   CopyBuffer(timezone_channel_handle, ZONE_UPPER_EDGE_BUFFER, 0, 1, upper_edge);
   CopyBuffer(timezone_channel_handle, ZONE_LOWER_EDGE_BUFFER, 0, 1, lower_edge);
   double ML = lower_edge[0];
   double MH = upper_edge[0];
   
   if(iClose(_Symbol,tf,1) > MH && iOpen(_Symbol,tf,1) <= MH){
      double p1_ = ML;
      double p2_ = MH;
      double p;
      if(instant_entry) p = ask;
      else p = order_price_ratio * (p1_-p2_) + p2_;
      double sl = p1_ - sl_offset_points*_Point;
      double tp1 = p + 1 * Rr * (p-sl);
      double tp2 = p + 2 * Rr * (p-sl);
      double lot = calculate_lot_size((p-sl)/_Point, risk);
      double lot_ = NormalizeDouble(floor(100*lot/2)/100, 2);
      if(instant_entry){
         if(close_only_half_size_on_tp){
            trade.Buy(lot_, _Symbol, p, sl, tp1, PositionComment);
            trade.Buy(lot_, _Symbol, p, sl, tp2, PositionComment);
         }else{
            trade.Buy(lot, _Symbol, p, sl, tp1, PositionComment);
         }
      }else{
         if(close_only_half_size_on_tp){
            trade.BuyLimit(lot_, p, _Symbol, sl, tp1, ORDER_TIME_GTC, 0, PositionComment);
            trade.BuyLimit(lot_, p, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, PositionComment);
         }else{
            trade.BuyLimit(lot, p, _Symbol, sl, tp1, ORDER_TIME_GTC, 0, PositionComment);
         }
      }

   }else if(iClose(_Symbol,tf,1) < ML && iOpen(_Symbol,tf,1) >= ML){
      double p1_ = MH;
      double p2_ = ML;
      double p;
      if(instant_entry) p = bid;
      else p = order_price_ratio * (p1_-p2_) + p2_;
      double sl = p1_ + sl_offset_points*_Point;
      double tp1 = p + 1 * Rr * (p-sl);
      double tp2 = p + 2 * Rr * (p-sl);
      double lot = calculate_lot_size((sl-p)/_Point, risk);
      double lot_ = NormalizeDouble(floor(100*lot/2)/100, 2);
      if(instant_entry){
         if(close_only_half_size_on_tp){
            trade.Sell(lot_, _Symbol, p, sl, tp1, PositionComment);
            trade.Sell(lot_, _Symbol, p, sl, tp2, PositionComment);
         }else{
            trade.Sell(lot, _Symbol, p, sl, tp1, PositionComment);
         }
      }else{
         if(close_only_half_size_on_tp){
            trade.SellLimit(lot_, p, _Symbol, sl, tp1, ORDER_TIME_GTC, 0, PositionComment);
            trade.SellLimit(lot_, p, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, PositionComment);
         }else{
            trade.SellLimit(lot, p, _Symbol, sl, tp1, ORDER_TIME_GTC, 0, PositionComment);
         }
      }
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
            DeleteAllOrders(trade);
         }
      }
   }   
}


void run_exit_policy(void){
   if(after_terminate_time_exit_policy==EXIT_POLICY_INSTANT){
      CloseAllPositions(trade);
      return;
      
   }else if(after_terminate_time_exit_policy==EXIT_POLICY_BREAKEVEN){
      ulong pos_tickets[];
      GetMyPositionsTickets(Magic, pos_tickets);
      int npos = ArraySize(pos_tickets);  
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(pos_type==POSITION_TYPE_BUY){
            double bidprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bidprice-open_price)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
         }else if(pos_type==POSITION_TYPE_SELL){
            double askprice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (open_price-askprice)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);              
         }
      }
      return;
   }
}


double OnTester(void){
   return prop_challenge_criteria.get_results();
}