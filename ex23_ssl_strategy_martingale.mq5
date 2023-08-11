/*
SSL indicator EA implemented with martingale

Strategy:

*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>


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
input int rsi_period = 0; // RSI period for confirmation (set 0 to disable)
input int ema_period = 0; // EMA period for confirmation (set 0 to disable)
input int adx_period = 0; // ADX period for confirmation (set 0 to disable)
input double adx_threshold = 25;

input group "Position settings"
input bool multiple_entries = false;  // multiple entries in SSL
input int stop_limit_offset_points = 0;  // stop limit offset points (set 0 for instant entry)
input double lot_size = 0.01;  // initial lot size
input double martingale_factor = 2.0;
input int target_profit_points = 500;  // target profit points
input int tsl_offset_points = 0;  //TSL offset points (set 0 to disable)

input group "Prop challenge criteria"
input double prop_challenge_min_profit_usd = 800; // Min profit desired(usd);
input double prop_challenge_max_drawdown_usd = 1200;  // Max drawdown desired(usd);
input double prop_challenge_daily_loss_limit = 300;  // Max loss (usd) in one day

input group "EA settings"
input double equity_stop_trading = 0;  // Stop trading if account equity is above this:
input string PositionComment = "";
input int Magic = 230;  // EA's magic number

input group "News Handling"
input int stop_minutes_before_news = 0;
input int stop_minutes_after_news = 0;
input string country_name = "US";
input string important_news = "CPI;Interest;Nonfarm;Unemployment;GDP;NFP;PMI";

CTrade trade;
int ssl_handle, rsi_handle, ema_handle, adx_handle;
ENUM_TIMEFRAMES tf;
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
   ssl_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\ssl.ex5", ssl_period, true, 0, min_ssl_breaking_points, multiple_entries);
   ChartIndicatorAdd(0, 0, ssl_handle);
   if(rsi_period>0) rsi_handle = iRSI(_Symbol, tf, rsi_period, PRICE_CLOSE);
   if(ema_period>0) ema_handle = iMA(_Symbol, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);
   if(adx_period>0) adx_handle = iADXWilder(_Symbol, tf, adx_period);
   prop_challenge_criteria = PropChallengeCriteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, MONTH_ALL, Magic);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(ssl_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(ema_handle);
   IndicatorRelease(adx_handle);
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
   prop_challenge_criteria.update();
   period_prof = prop_challenge_criteria.get_current_period_profit();
   period_drawdown = prop_challenge_criteria.get_current_period_drawdown();
   today_profit = prop_challenge_criteria.get_today_profit();
   risk = MathMax(MathMin(risk_original, prop_challenge_daily_loss_limit+today_profit), 0);
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || !MQLInfoInteger(MQL_OPTIMIZATION)) Comment("EA: ", Magic, "\nToday profit: ", int(today_profit),"\nPeriod Profit: ", int(period_prof), " / " , int(prop_challenge_min_profit_usd), "\nPeriod Drawdown: ", int(period_drawdown), " / " , int(prop_challenge_max_drawdown_usd), "\nRisk: ", int(risk), " / " , int(prop_challenge_daily_loss_limit));

   
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

   if(ssl_buy && rsi_confirmed(true) && ema_confirmed(true) && adx_confirmed(true)){  // enter buy
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
   }else if(ssl_sell && rsi_confirmed(false) && ema_confirmed(false) && adx_confirmed(false)){  // enter sell
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
   double val[];
   ArraySetAsSeries(val, true);
   CopyBuffer(rsi_handle, 0, 1, 1, val);
   if(buy_or_sell && val[0]>50) return true;
   if(!buy_or_sell && val[0]<50) return true;
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

bool adx_confirmed(bool buy_or_sell){
   if(adx_period<=0) return true;
   double val[], plus_line[], minus_line[];
   ArraySetAsSeries(val, true);
   ArraySetAsSeries(plus_line, true);
   ArraySetAsSeries(minus_line, true);
   CopyBuffer(adx_handle, 0, 1, 1, val);
   CopyBuffer(adx_handle, 1, 1, 1, plus_line);
   CopyBuffer(adx_handle, 2, 1, 1, minus_line);
   if(buy_or_sell && val[0]>=adx_threshold && plus_line[0]>minus_line[0]) return true;
   if(!buy_or_sell && val[0]>=adx_threshold && plus_line[0]<minus_line[0]) return true;
   return false;   
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