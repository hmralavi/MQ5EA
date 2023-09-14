/*
SSL indicator EA

Strategy:

TODO:
   1- news ---> us to usd, add other currencies
   2- risk coefficient (increase or decrease throuoght the day) ---> DONE
   3- confirmation from other timeframe ssl (omid's idea) ----> DONE
   4- do not trade if a good leg is already appeared in the day
   5- attention: stop limits make huge difference between real tick testing and 1-min-OHLC testing.
   6- place stoploss before the last candle (omid's idea) ----> DONE
*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>

enum ENUM_IN_LOSS_SSL_CHANGED_POLICY{
   IN_LOSS_SSL_CHANGED_POLICY_NOTHING = 0,  // do nothing
   IN_LOSS_SSL_CHANGED_POLICY_BREAKEVEN = 1,  // breakeven
   IN_LOSS_SSL_CHANGED_POLICY_INSTANT = 2,  // instant exit
};

enum ENUM_IN_PROFIT_SSL_CHANGED_POLICY{
   IN_PROFIT_SSL_CHANGED_POLICY_NOTHING = 0, // do nothing
   IN_PROFIT_SSL_CHANGED_POLICY_INSTANT = 1  // instant exit
};

input group "Time settings"
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_M5;  // Time Frame
input bool trade_only_in_session_time = false;  // entries only in specific session time of the day
input double session_start_hour = 5.0;          // session start hour (server time)
input double session_end_hour = 13.0;           // session end hour (server time)
input double terminate_hour = 0.0;              // terminate all positions/orders hour (set 0 to disable)
input bool no_trade_weekend = false;  // no trade on weekend (fri)

input group "Main SSL settings"
input int ssl_period = 14; // SSL period
input int min_ssl_breaking_points = 0;  // minimum points to consider SSL is broken

input group "SSL confirmation"
input int cnfrm_ssl_period = 0;  // confirmation SSL period (set 0 to disable)
input ENUM_CUSTOM_TIMEFRAMES cnfrm_ssl_tf = CUSTOM_TIMEFRAMES_M15;  // confirmation SSL timeframe
input int cnfrm_ssl_min_breaking_points = 0;  // minimum points to consider SSL is broken
input int cnfrm_ssl_min_length = 0;  // minimum SSL length (candles)
input int cnfrm_ssl_max_length = 5;  // maximum SSL length (candles)

input group "EMA confirmation"
input int ema_period = 0; // EMA period for confirmation (set 0 to disable)

input group "RSI confirmation"
input int rsi_period = 0; // RSI period for confirmation (set 0 to disable)
input int rsi_divergence_valid_ncandles = 5;  // number of candles that a divergence remains valid
input int rsi_divergence_ncandles_peak = 1;  // number of candles to detect peak for RSI divergence
input int rsi_divergence_npeaks = 2;  // number of peaks in RSI to detect divergence
input double rsi_divergence_min_slope = 20;  // Min slope for RSI divergence
input bool rsi_divergence_head_shoulder_only = false;  // Head&shoulder RSI divergence only

input group "Position settings"
input int stop_limit_offset_points = 0;  // stop limit offset points (set 0 for instant entry)
input int multiple_entry_offset_points = 0;  // multiple entry: max offset points from SSL  (set 0 to disable multiple entry)
input double risk_original = 100;  // risk usd per trade
input double risk_modification_factor = 1; // daily risk modification factor
input double Rr = 0.0; // reward/risk ratio (set 0 to disable tp)
input double sl_level_ratio = 0;  // sl level ratio (0 on ssl, 1 on open price)
input int sl_offset_points = 0;  // sl offset points
input int sl_min_points = 0;  // sl min points (set 0 to ignore)
input int sl_max_points = 0;  // sl max points (set 0 to ignore)
input int tsl_offset_points = 0;  //TSL offset points from ssl (set 0 to disable)
input double riskfree_ratio = 0.0;  // RiskFree (proportion of SL) (set 0 to disable)
input ENUM_IN_PROFIT_SSL_CHANGED_POLICY in_profit_exit_policy = IN_PROFIT_SSL_CHANGED_POLICY_NOTHING;  // What to do when SSL trend changes in profit?
input ENUM_IN_LOSS_SSL_CHANGED_POLICY in_loss_exit_policy = IN_LOSS_SSL_CHANGED_POLICY_NOTHING;  // What to do when SSL trend changes in loss?

input group "Settings for prop challenge report"
input double prop_challenge_min_profit_usd = 800; // Profit (usd)
input double prop_challenge_max_drawdown_usd = 1200;  //  Drawdown (usd)
input double prop_challenge_daily_loss_limit = 450;  // Daily loss (usd)

input group "EA settings"
input double max_daily_loss_allowed = 0;  // Max daily loss allowed
input double max_daily_profit_allowed = 0; // Max daily profit allowd
input double equity_above_stop_trading = 0;  // Stop trading if account equity is above this:
input double equity_below_stop_trading = 0;  // Stop trading if account equity is below this:
input string PositionComment = "";
input int Magic = 220;  // EA's magic number

input group "News Handling"
input int no_new_position_before_news_minutes = 0;
input int no_new_position_after_news_minutes = 0;
input int close_positions_before_news_minutes = 0;
input int close_positions_after_news_minutes = 0;
input int backtesting_news_time_shift_minutes = 0;

CTrade trade;
int ssl_handle, cnfrm_ssl_handle, rsi_handle, ema_handle;
ENUM_TIMEFRAMES tf;
double risk;
CNews today_news;
bool ignore_new_candle = false;

#define SSL_UPPER_BUFFER 0
#define SSL_LOWER_BUFFER 1
#define SSL_BUY_BUFFER 2
#define SSL_SELL_BUFFER 3
#define SSL_CURRENT_LENGTH_BUFFER 6

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.LogLevel(LOG_LEVEL_NO);
   tf = convert_tf(custom_timeframe);
   ssl_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\SSL_NEW.ex5", ssl_period, true, min_ssl_breaking_points, multiple_entry_offset_points>0, multiple_entry_offset_points, 0, false, 0, 1);
   ChartIndicatorAdd(0, 0, ssl_handle);
   if(cnfrm_ssl_period>0) cnfrm_ssl_handle = iCustom(_Symbol, convert_tf(cnfrm_ssl_tf), "..\\Experts\\mq5ea\\indicators\\SSL_NEW.ex5", cnfrm_ssl_period, true, cnfrm_ssl_min_breaking_points, false, 0, 0, false, 0, 1);
   if(rsi_period>0) rsi_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\HARSI.ex5", rsi_period, 7, PRICE_TYPICAL, rsi_period, true, rsi_divergence_ncandles_peak, 0, 0, 40, rsi_divergence_npeaks, false, false);
   if(ema_period>0) ema_handle = iMA(_Symbol, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);
   risk = risk_original;
   ignore_new_candle = false;
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(ssl_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(ema_handle);
}

void OnTick()
{
   if(equity_above_stop_trading>0){
      double acc_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(acc_eq>equity_above_stop_trading){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   if(equity_below_stop_trading>0){
      double acc_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(acc_eq<equity_below_stop_trading){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   double ea_today_profit;
   vector<double> all_risks = vector::Zeros(3);
   ea_today_profit = calculate_today_profit(Magic);
   all_risks[0] = risk_original_modified();
   all_risks[1] = ea_today_profit+max_daily_loss_allowed;
   all_risks[2] = max_daily_profit_allowed-ea_today_profit;
   risk = MathMax(all_risks.Min(), 0);
   if((!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)) && !MQLInfoInteger(MQL_OPTIMIZATION) && !MQLInfoInteger(MQL_FORWARD)){
      double ea_profit, ea_drawdown;
      int ea_total_days;
      calculate_all_trades_profit_drawdown(Magic, ea_profit, ea_drawdown, ea_total_days);
      Comment(StringFormat("EA: %d     Current allowed risk: %.0f     Today profit: %.0f (%.0f, %.0f)     Total profit: %.0f     Total drawdown: %.0f     Total days: %d", Magic, risk, ea_today_profit,-max_daily_loss_allowed, max_daily_profit_allowed, ea_profit, ea_drawdown, ea_total_days));
   }
   
   if(terminate_hour>0){
      if(!is_session_time_allowed_double(session_start_hour, terminate_hour)){
         run_early_exit_policy(0);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   
   if(no_new_position_after_news_minutes>0 || no_new_position_before_news_minutes>0 || close_positions_after_news_minutes>0 || close_positions_before_news_minutes>0){
      update_news();
      int nnews = ArraySize(today_news.news);
      if(nnews>0){
         for(int inews=0;inews<nnews;inews++){
            datetime newstime = today_news.news[inews].time + backtesting_news_time_shift_minutes*60;
            int nminutes = (int)(TimeCurrent()-newstime)/60;
            if((nminutes<=0 && -nminutes<=close_positions_before_news_minutes && close_positions_before_news_minutes>0) || (nminutes>=0 && nminutes<=close_positions_after_news_minutes && close_positions_after_news_minutes>0)){
               if(ArraySize(pos_tickets)+ArraySize(ord_tickets)>0){
                  PrintFormat("%d minutes %s news `%s` with importance %d. closing the positions...", 
                              MathAbs(nminutes),nminutes>0?"after":"before",today_news.news[inews].title, today_news.news[inews].importance);
                  DeleteAllOrders(trade);
                  CloseAllPositions(trade);
               }
               return;
            }
            if((nminutes<=0 && -nminutes<=no_new_position_before_news_minutes && no_new_position_before_news_minutes>0) || (nminutes>=0 && nminutes<=no_new_position_after_news_minutes && no_new_position_after_news_minutes>0)) return;
         }
      }
   }
   
   if(riskfree_ratio>0){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_sl = PositionGetDouble(POSITION_SL);
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double curr_tp = PositionGetDouble(POSITION_TP);
         if(pos_type==POSITION_TYPE_BUY && curr_sl<open_price && (curr_price-open_price)>=riskfree_ratio*(open_price-curr_sl)){
            double new_sl = (open_price-curr_sl)*riskfree_ratio + curr_sl;
            trade.PositionModify(pos_tickets[ipos], new_sl, curr_tp);
         }else if(pos_type==POSITION_TYPE_SELL && curr_sl>open_price && (open_price-curr_price)>=riskfree_ratio*(curr_sl-open_price)){
            double new_sl = (open_price-curr_sl)*riskfree_ratio + curr_sl;
            trade.PositionModify(pos_tickets[ipos], new_sl, curr_tp);
         }
      }
   }
     
   if(tsl_offset_points>0){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_sl = PositionGetDouble(POSITION_SL);
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double curr_tp = PositionGetDouble(POSITION_TP);
         if(pos_type==POSITION_TYPE_BUY){
            TrailingStoploss(trade, pos_tickets[ipos], (curr_price-get_ssl_upper())/_Point + tsl_offset_points);
         }else if(pos_type==POSITION_TYPE_SELL){
            TrailingStoploss(trade, pos_tickets[ipos], (get_ssl_lower()-curr_price)/_Point + tsl_offset_points);
         }   
      }
   }   
   
   if(!IsNewCandle(tf, 5) && !ignore_new_candle) return;
   
   bool ssl_buy = get_ssl_buy(1);
   bool ssl_sell = get_ssl_sell(1);
   double ssl_upper = get_ssl_upper(1);
   double ssl_lower = get_ssl_lower(1);
   
   if(!ssl_buy && !ssl_sell) return;
   
   if((ArraySize(pos_tickets)+ArraySize(ord_tickets))>0){
      DeleteAllOrders(trade);
      if(multiple_entry_offset_points>0){
         if(ssl_upper==EMPTY_VALUE && ssl_lower!=EMPTY_VALUE) run_early_exit_policy(1); // close only buy positions
         if(ssl_upper!=EMPTY_VALUE && ssl_lower==EMPTY_VALUE) run_early_exit_policy(2); // close only sell positions
      }else{
         run_early_exit_policy(0);
      }
      ignore_new_candle = true;
   }
    
   ArrayResize(pos_tickets, 0);
   ArrayResize(ord_tickets, 0);
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(multiple_entry_offset_points>0){
      if(!AllPositionsRiskfreed()) return;
   }else{
      if(ArraySize(pos_tickets)>0) return;
   }
   if(ArraySize(ord_tickets)>0) return;
   
   ignore_new_candle = false;
   
   if(!is_session_time_allowed_double(session_start_hour, session_end_hour) && trade_only_in_session_time) return;
   if(is_weekend() && no_trade_weekend) return;

   if(ssl_buy && ssl_confirmed(true) && rsi_confirmed(true) && ema_confirmed(true)){  // enter buy
      double p = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(stop_limit_offset_points>0) p = MathMax(iHigh(_Symbol, tf, 1), p) + stop_limit_offset_points*_Point;
      double sl = MathMin(ssl_upper, iLow(_Symbol, tf, 1));
      sl = sl + (p-sl)*sl_level_ratio - sl_offset_points*_Point;
      if(p<sl) return;
      if((sl_min_points>0 && (p-sl)<sl_min_points*_Point) || (sl_max_points>0 && (p-sl)>sl_max_points*_Point)) return;
      double lot_size = normalize_volume(calculate_lot_size((p-sl)/_Point, risk));
      p = NormalizeDouble(p, _Digits);
      sl = NormalizeDouble(sl, _Digits);
      double tp = 0;
      if(Rr>0) tp = p + (p-sl)*Rr;
      tp = NormalizeDouble(tp, _Digits);
      if(stop_limit_offset_points>0) trade.BuyStop(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);
      else trade.Buy(lot_size, _Symbol, p, sl, tp, PositionComment);
   }else if(ssl_sell && ssl_confirmed(false) && rsi_confirmed(false) && ema_confirmed(false)){  // enter sell
      double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);      
      if(stop_limit_offset_points>0) p = MathMin(iLow(_Symbol, tf, 1), p) - stop_limit_offset_points*_Point;
      double sl = MathMax(ssl_lower, iHigh(_Symbol, tf, 1));
      sl = sl + (p-sl)*sl_level_ratio + sl_offset_points*_Point;;
      if(p>sl) return;
      if((sl_min_points>0 && (sl-p)<sl_min_points*_Point) || (sl_max_points>0 && (sl-p)>sl_max_points*_Point)) return;
      double lot_size = normalize_volume(calculate_lot_size((sl-p)/_Point, risk));
      p = NormalizeDouble(p, _Digits);
      sl = NormalizeDouble(sl, _Digits);
      double tp = 0;
      if(Rr>0) tp = p + (p-sl)*Rr;
      tp = NormalizeDouble(tp, _Digits);
      if(stop_limit_offset_points>0) trade.SellStop(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);
      else trade.Sell(lot_size, _Symbol, p, sl, tp, PositionComment);
   }

}

double get_ssl_upper(int shift=0){
   double val[1];
   CopyBuffer(ssl_handle, SSL_UPPER_BUFFER, shift, 1, val);
   return val[0];
}

double get_ssl_lower(int shift=0){
   double val[1];
   CopyBuffer(ssl_handle, SSL_LOWER_BUFFER, shift, 1, val);
   return val[0];
}

bool get_ssl_buy(int shift=0){
   double val[1];
   CopyBuffer(ssl_handle, SSL_BUY_BUFFER, shift, 1, val);
   return val[0]==EMPTY_VALUE?false:true;
}

bool get_ssl_sell(int shift=0){
   double val[1];
   CopyBuffer(ssl_handle, SSL_SELL_BUFFER, shift, 1, val);
   return val[0]==EMPTY_VALUE?false:true;
}

bool ssl_confirmed(bool buy_or_sell){
   if(cnfrm_ssl_period<=0) return true;
   double upper[1], length[1];
   int shift = 0;
   CopyBuffer(cnfrm_ssl_handle, SSL_UPPER_BUFFER, shift, 1, upper);
   CopyBuffer(cnfrm_ssl_handle, SSL_CURRENT_LENGTH_BUFFER, shift, 1, length);
   bool cnfrm_buy_or_sell = upper[0]==EMPTY_VALUE?false:true;
   if(cnfrm_buy_or_sell != buy_or_sell) return false;
   if(length[0]>=cnfrm_ssl_min_length && length[0]<=cnfrm_ssl_max_length) return true;
   return false;
}

bool rsi_confirmed(bool buy_or_sell){
   if(rsi_period<=0) return true;
   double rsival[], bullish_divergence[], bearish_divergence[];
   ArraySetAsSeries(rsival, true);
   ArraySetAsSeries(bullish_divergence, true);
   ArraySetAsSeries(bearish_divergence, true);
   CopyBuffer(rsi_handle, 5, 1, rsi_divergence_valid_ncandles, rsival);
   CopyBuffer(rsi_handle, 6, 1, rsi_divergence_valid_ncandles, bullish_divergence);
   CopyBuffer(rsi_handle, 7, 1, rsi_divergence_valid_ncandles, bearish_divergence);
   for(int i=0;i<rsi_divergence_valid_ncandles;i++){
      if(buy_or_sell && bullish_divergence[i]!=EMPTY_VALUE) return true;
      else if(!buy_or_sell && bearish_divergence[i]!=EMPTY_VALUE) return true;
   }
   return false;   
}

bool ema_confirmed(bool buy_or_sell){
   if(ema_period<=0) return true;
   double val[];
   ArraySetAsSeries(val, true);
   CopyBuffer(ema_handle, 0, 1, 1, val);
   if(buy_or_sell && iClose(_Symbol, tf, 1)>val[0]) return true;
   if(!buy_or_sell && iClose(_Symbol, tf, 1)<val[0]) return true;
   return false;   
}

void run_early_exit_policy(int which_positions_type){ // which_positions_type: 0:all, 1:buys only, 2:sell only
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((which_positions_type==1 && pos_type==POSITION_TYPE_SELL) || (which_positions_type==2 && pos_type==POSITION_TYPE_BUY)) continue;
      double current_profit = PositionGetDouble(POSITION_PROFIT);
      if(current_profit>=0){
         if(in_profit_exit_policy==IN_PROFIT_SSL_CHANGED_POLICY_INSTANT) trade.PositionClose(pos_tickets[ipos]);
      }else if(current_profit<0){
         if(in_loss_exit_policy==IN_LOSS_SSL_CHANGED_POLICY_INSTANT) trade.PositionClose(pos_tickets[ipos]);
         else if(in_loss_exit_policy==IN_LOSS_SSL_CHANGED_POLICY_BREAKEVEN){
            double current_sl = PositionGetDouble(POSITION_SL);
            double current_tp = PositionGetDouble(POSITION_TP);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);         
            if(pos_type==POSITION_TYPE_BUY && current_sl<open_price && (current_tp>open_price || current_tp==0)) trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
            else if(pos_type==POSITION_TYPE_SELL && current_sl>open_price && (current_tp<open_price || current_tp==0)) trade.PositionModify(pos_tickets[ipos], current_sl, open_price); 
         }
      }
   }
}

bool AllPositionsRiskfreed(void){  // checks if all current position are risk freed
   bool result = true;
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);  
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double current_sl = PositionGetDouble(POSITION_SL);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(pos_type==POSITION_TYPE_BUY && current_sl<open_price) result = false;
      else if(pos_type==POSITION_TYPE_SELL && current_sl>open_price) result = false;
      if(!result) break;
   }
   return result;
}

double risk_original_modified(void){
   MqlDateTime time_start, time_end;
   TimeToStruct(TimeCurrent(), time_start);
   TimeToStruct(TimeCurrent(), time_end);
   time_start.hour=0;
   time_start.min=0;
   time_start.sec=0;
   time_end.hour=23;
   time_end.min=59;
   time_end.sec=59;

   datetime datetime_start = StructToTime(time_start);
   datetime datetime_end = StructToTime(time_end);

   HistorySelect(datetime_start, datetime_end);
   int ndeals = HistoryDealsTotal();
   int eadeals = 0;
   for(int i=0;i<ndeals;i++){
      ulong dealticket = HistoryDealGetTicket(i);
      int magic = (int)HistoryDealGetInteger(dealticket, DEAL_MAGIC);
      if(magic != Magic) continue;
      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN) eadeals++;
   }
   double coef = MathPow(risk_modification_factor, eadeals);
   return risk_original * coef; 
}

bool is_weekend(void){
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week==5;
}

double OnTester(void){
   return print_prop_challenge_report(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, prop_challenge_daily_loss_limit);
}

void update_news(void){
   static int last_day;
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   if(last_day != today.day){
      last_day = today.day;
      today_news = CNews(0,0,"US",MY_IMPORTANT_NEWS);
      ArrayPrint(today_news.news);
   }
}