/*
SSL indicator EA

Strategy:

*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>

enum ENUM_EARLY_EXIT_POLICY{
   EARLY_EXIT_POLICY_BREAKEVEN = 0,  // Breakeven if in loss/Instant exit if in profit
   EARLY_EXIT_POLICY_INSTANT = 1  // instant exit anyway
};

input group "Time settings"
input bool use_custom_timeframe = false;
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_M5;
input bool trade_only_in_session_time = false;  // entries only in specific session time of the day
input double session_start_hour = 5.0;          // session start hour (server time)
input double session_end_hour = 13.0;           // session end hour (server time)
input double terminate_hour = 0.0;              // terminate all positions/orders hour (set 0 to disable)

input group "Indicator settings"
input int ssl_period = 14; // SSL period
input int min_ssl_breaking_points = 0;  // minimum points to consider SSL is broken
input int ema_period = 0; // EMA period for confirmation (set 0 to disable)
input int rsi_period = 0; // RSI period for confirmation (set 0 to disable)
input int rsi_divergence_valid_ncandles = 5;  // number of candles that a divergence remains valid
input int rsi_divergence_ncandles_peak = 1;  // number of candles to detect peak for RSI divergence
input int rsi_divergence_npeaks = 2;  // number of peaks in RSI to detect divergence
input double rsi_divergence_min_slope = 20;  // Min slope for RSI divergence
input bool rsi_divergence_head_shoulder_only = false;  // Head&shoulder RSI divergence only

input group "Position settings"
input bool multiple_entries = false;  // multiple entries in SSL
input int stop_limit_offset_points = 0;  // stop limit offset points (set 0 for instant entry)
input double risk_original = 100;  // risk usd per trade
input double Rr = 0.0; // reward/risk ratio (set 0 to disable tp)
input int sl_offset_points = 0;  // sl offset points from ssl
input int tsl_offset_points = 0;  //TSL offset points from ssl (set 0 to disable)
input double riskfree_ratio = 0.0;  // RiskFree (proportion of SL) (set 0 to disable)
input ENUM_EARLY_EXIT_POLICY early_exit_policy = EARLY_EXIT_POLICY_BREAKEVEN;  // how exit position when trend changes?

input group "Run for prop challenge"
input bool prop_challenge_criteria_enabled = true; // Enabled?
input double prop_challenge_min_profit_usd = 800; // Min profit desired(usd);
input double prop_challenge_max_drawdown_usd = 1200;  // Max drawdown desired(usd);
input double prop_challenge_daily_loss_limit = 450;  // Max loss (usd) in one day
input double new_risk_if_prop_passed = 10; // new risk (usd) if prop challenge is passed.

input group "EA settings"
input double equity_stop_trading = 0;  // Stop trading if account equity is above this:
input string PositionComment = "";
input int Magic = 220;  // EA's magic number

input group "News Handling"
input int stop_minutes_before_news = 0;
input int stop_minutes_after_news = 0;
input string country_name = "US";
input string important_news = MY_IMPORTANT_NEWS;

CTrade trade;
int ssl_handle, rsi_handle, ema_handle;
ENUM_TIMEFRAMES tf;
double risk;
PropChallengeCriteria prop_challenge_criteria;
CNews today_news;

#define SSL_UPPER_BUFFER 0
#define SSL_LOWER_BUFFER 1
#define SSL_BUY_BUFFER 2
#define SSL_SELL_BUFFER 3

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.LogLevel(LOG_LEVEL_NO);
   if(use_custom_timeframe) tf = convert_tf(custom_timeframe);
   else tf = _Period;
   ssl_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\SSL_NEW.ex5", ssl_period, true, min_ssl_breaking_points, multiple_entries, 10, 5, true, 0, 1);
   ChartIndicatorAdd(0, 0, ssl_handle);
   if(rsi_period>0) rsi_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\HARSI.ex5", rsi_period, 7, PRICE_TYPICAL, rsi_period, true, rsi_divergence_ncandles_peak, 0, 0, 40, rsi_divergence_npeaks, false, false);
   if(ema_period>0) ema_handle = iMA(_Symbol, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);
   risk = risk_original;
   prop_challenge_criteria = PropChallengeCriteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, MONTH_ALL, Magic);
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

   if(equity_stop_trading>0){
      double acc_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(acc_eq>=equity_stop_trading){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   double period_prof, period_drawdown, today_profit; 
   if(prop_challenge_criteria_enabled){
      prop_challenge_criteria.update();
      period_prof = prop_challenge_criteria.get_current_period_profit();
      period_drawdown = prop_challenge_criteria.get_current_period_drawdown();
      today_profit = prop_challenge_criteria.get_today_profit();
      risk = MathMax(MathMin(risk_original, prop_challenge_daily_loss_limit+today_profit), 0);
      if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || !MQLInfoInteger(MQL_OPTIMIZATION)) Comment("EA: ", Magic, "\nToday profit: ", int(today_profit),"\nPeriod Profit: ", int(period_prof), " / " , int(prop_challenge_min_profit_usd), "\nPeriod Drawdown: ", int(period_drawdown), " / " , int(prop_challenge_max_drawdown_usd), "\nRisk: ", int(risk), " / " , int(prop_challenge_daily_loss_limit));
      //if(period_prof>=prop_challenge_min_profit_usd*1.01 && risk>new_risk_if_prop_passed){
      //   DeleteAllOrders(trade);
      //   CloseAllPositions(trade);
      //}
   }
   
   if(terminate_hour>0){
      if(!is_session_time_allowed_double(session_start_hour, terminate_hour)){
         DeleteAllOrders(trade);
         CloseAllPositions(trade);
         return;
      }
   }
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   
   if(stop_minutes_before_news>0 || stop_minutes_after_news>0){
      update_news();
      int nnews = ArraySize(today_news.news);
      if(nnews>0){
         for(int inews=0;inews<nnews;inews++){
            datetime newstime = today_news.news[inews].time;
            int nminutes = (int)(TimeCurrent()-newstime)/60;
            if((nminutes<0 && -nminutes<=stop_minutes_before_news && stop_minutes_before_news>0) || (nminutes>0 && nminutes<=stop_minutes_after_news && stop_minutes_after_news>0)){
               if(ArraySize(pos_tickets)+ArraySize(ord_tickets)>0){
                  PrintFormat("%d minutes %s news `%s` with importance %d. closing the positions...", 
                              MathAbs(nminutes),nminutes>0?"after":"before",today_news.news[inews].title, today_news.news[inews].importance);
                  DeleteAllOrders(trade);
                  CloseAllPositions(trade);
               }
               return;
            }
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
            trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
         }else if(pos_type==POSITION_TYPE_SELL && curr_sl>open_price && (open_price-curr_price)>=riskfree_ratio*(curr_sl-open_price)){
            trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
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
   
   if(!IsNewCandle(tf, 1)) return;
   
   bool ssl_buy = get_ssl_buy(1);
   bool ssl_sell = get_ssl_sell(1);
   double ssl_upper = get_ssl_upper(1);
   double ssl_lower = get_ssl_lower(1);
   
   if(ssl_buy || ssl_sell){
      DeleteAllOrders(trade);
      if(multiple_entries){
         if(ssl_upper==EMPTY_VALUE && ssl_lower!=EMPTY_VALUE) run_early_exit_policy(1); // close only buy positions
         if(ssl_upper!=EMPTY_VALUE && ssl_lower==EMPTY_VALUE) run_early_exit_policy(2); // close only sell positions
      }else{
         run_early_exit_policy(0);
      }
   }
   

   
   ArrayResize(pos_tickets, 0);
   ArrayResize(ord_tickets, 0);
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(multiple_entries){
      if(!AllPositionsRiskfreed()) return;
   }else{
      if(ArraySize(pos_tickets)>0) return;
   }
   if(ArraySize(ord_tickets)>0) return;
   
   if(!is_session_time_allowed_double(session_start_hour, session_end_hour) && trade_only_in_session_time) return;

   if(ssl_buy && rsi_confirmed(true) && ema_confirmed(true)){  // enter buy
      double p = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(stop_limit_offset_points>0) p = MathMax(iHigh(_Symbol, tf, 1), p) + stop_limit_offset_points*_Point;
      double sl = MathMin(ssl_upper, iLow(_Symbol, tf, 1)) - sl_offset_points*_Point;
      if(p<sl) return;
      double lot_size = normalize_volume(calculate_lot_size((p-sl)/_Point, risk));
      p = NormalizeDouble(p, _Digits);
      sl = NormalizeDouble(sl, _Digits);
      double tp = 0;
      if(Rr>0) tp = p + (p-sl)*Rr;
      tp = NormalizeDouble(tp, _Digits);
      if(stop_limit_offset_points>0) trade.BuyStop(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);
      else trade.Buy(lot_size, _Symbol, p, sl, tp, PositionComment);
   }else if(ssl_sell && rsi_confirmed(false) && ema_confirmed(false)){  // enter sell
      double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(stop_limit_offset_points>0) p = MathMin(iLow(_Symbol, tf, 1), p) - stop_limit_offset_points*_Point;
      double sl = MathMax(ssl_lower, iHigh(_Symbol, tf, 1)) + sl_offset_points*_Point;
      if(p>sl) return;
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
   if(early_exit_policy==EARLY_EXIT_POLICY_INSTANT){
      CloseAllPositions(trade, which_positions_type);      
   }else if(early_exit_policy==EARLY_EXIT_POLICY_BREAKEVEN){
      ulong pos_tickets[];
      GetMyPositionsTickets(Magic, pos_tickets);
      int npos = ArraySize(pos_tickets);  
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(pos_type==POSITION_TYPE_BUY && current_sl<open_price && (current_tp>open_price || current_tp==0) && (which_positions_type==0 || which_positions_type==1)){
            double bidprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bidprice-open_price)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
         }else if(pos_type==POSITION_TYPE_SELL && current_sl>open_price && (current_tp<open_price || current_tp==0) && (which_positions_type==0 || which_positions_type==2)){
            double askprice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (open_price-askprice)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);              
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

double OnTester(void){
   return print_prop_challenge_report(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, prop_challenge_daily_loss_limit*1.1);
}

void update_news(void){
   static int last_day;
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   if(last_day != today.day){
      last_day = today.day;
      today_news = CNews(0,0,country_name,important_news);
      ArrayPrint(today_news.news);
   }
}