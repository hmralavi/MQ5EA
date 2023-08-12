/*
Buy and sell based on RSI. implemented with martingale.

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
input ENUM_APPLIED_PRICE rsi_source = PRICE_CLOSE;
input int rsi_period = 14; // RSI period
input double rsi_threshold = 20;  // RSI threshold (offset from 50 midline)

input group "Martingale settings"
input double lot_size = 0.01;
input double lot_factor = 2;
input double target_profit_usd = 40;
input double tsl_offset_points = 0;

input group "Prop challenge criteria"
input double prop_challenge_min_profit_usd = 800; // Min profit desired(usd);
input double prop_challenge_max_drawdown_usd = 1200;  // Max drawdown desired(usd);
input double prop_challenge_daily_loss_limit = 300;  // Max loss (usd) in one day

input group "EA settings"
input double equity_stop_trading = 0;  // Stop trading if account equity is above this:
input string PositionComment = "";
input int Magic = 240;  // EA's magic number

input group "News Handling"
input int stop_minutes_before_news = 0;
input int stop_minutes_after_news = 0;
input string country_name = "US";
input string important_news = "CPI;Interest;Nonfarm;Unemployment;GDP;NFP;PMI";

CTrade trade;
int rsi_handle;
ENUM_TIMEFRAMES tf;
CNews today_news;
double buy_lot, sell_lot, both_lot;

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
   rsi_handle = iRSI(_Symbol, tf, rsi_period, rsi_source);
   ChartIndicatorAdd(0, 0, rsi_handle);
   buy_lot = lot_size/lot_factor;
   sell_lot = lot_size/lot_factor;
   both_lot = lot_size/lot_factor;
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(rsi_handle);
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
   
   double buy_profit_points, sell_profit_points, buy_profit_usd, sell_profit_usd;
   calculate_profits(buy_profit_points, sell_profit_points, buy_profit_usd, sell_profit_usd);
   //if(buy_profit_usd>=target_profit_usd){
   //   CloseAllPositions(trade, 1);
   //   buy_lot = lot_size;
   //}
   //if(sell_profit_usd>=target_profit_usd){
   //   CloseAllPositions(trade, 2);
   //   sell_lot = lot_size;
   //}
   if((sell_profit_usd + buy_profit_usd)>=target_profit_usd){
      CloseAllPositions(trade, 0);
      both_lot = lot_size;
   }   
     
   //if(tsl_offset_points>0){
   //   int npos = ArraySize(pos_tickets);
   //   for(int ipos=0;ipos<npos;ipos++){
   //      PositionSelectByTicket(pos_tickets[ipos]);
   //      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   //      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
   //      double curr_sl = PositionGetDouble(POSITION_SL);
   //      double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   //      double curr_tp = PositionGetDouble(POSITION_TP);
   //      if(pos_type==POSITION_TYPE_BUY){
   //         TrailingStoploss(trade, pos_tickets[ipos], (curr_price-get_ssl_upper())/_Point + tsl_offset_points);
   //      }else if(pos_type==POSITION_TYPE_SELL){
   //         TrailingStoploss(trade, pos_tickets[ipos], (get_ssl_lower()-curr_price)/_Point + tsl_offset_points);
   //      }   
   //   }
   //}
   
   if(!IsNewCandle(tf, 1)) return;
   
   int buy_or_sell = buy_or_sell_signal();
   if(buy_or_sell==1){
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      buy_lot = NormalizeDouble(buy_lot*lot_factor, 2);
      both_lot = NormalizeDouble(both_lot*lot_factor, 2);
      trade.Buy(both_lot, _Symbol, ask, 0, 0, PositionComment);
   }else if(buy_or_sell==2){
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sell_lot = NormalizeDouble(sell_lot*lot_factor, 2);
      both_lot = NormalizeDouble(both_lot*lot_factor, 2);
      trade.Sell(both_lot, _Symbol, bid, 0, 0, PositionComment);
   }
}

int buy_or_sell_signal(){ // 0: nothing, 1:buy, 2:sell
   double val[];
   ArraySetAsSeries(val, true);
   CopyBuffer(rsi_handle, 0, 1, 2, val);
   if(val[0]>50+rsi_threshold && val[1]<50+rsi_threshold) return 2;
   if(val[0]<50-rsi_threshold && val[1]>50-rsi_threshold) return 1;
   return 0;   
}

void calculate_profits(double& buy_profit_points, double& sell_profit_points, double& buy_profit_usd, double& sell_profit_usd){
   double bp = 0;
   double sp = 0;
   double bu = 0;
   double su = 0;
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
      double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double prof = PositionGetDouble(POSITION_PROFIT);
      if(pos_type==POSITION_TYPE_BUY){
         bp += (curr_price - open_price)/_Point;
         bu += prof;
      }else if(pos_type==POSITION_TYPE_SELL){
         sp += (open_price - curr_price)/_Point;
         su += prof;
      }   
   }
   buy_profit_points = bp;
   sell_profit_points = sp;
   buy_profit_usd = bu;
   sell_profit_usd = su;
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