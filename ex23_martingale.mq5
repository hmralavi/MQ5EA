/*
Buy and sell based on multiple indicators; implemented with martingale.

Strategy:

*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>

enum ENUM_RSI_RULE{
   RSI_RULE_SIGN,
   RSI_RULE_BREAK
};

enum ENUM_TP_RULE{
   TP_RULE_COUNT_BASED,
   TP_RULE_LOT_BASED
};

input group "Time settings"
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_M5;
input bool trade_only_in_session_time = false;  // entries only in specific session time of the day
input double session_start_hour = 3.0;          // session start hour (server time)
input double session_end_hour = 22.0;           // session end hour (server time)
input bool dont_start_new_cycle_on_weekend = true;  // don't start new cycle on weekend (thu&fri)

input group "HARSI"
input int harsi_period = 14;
input int harsi_smoothing = 7;
input ENUM_APPLIED_PRICE rsi_source = PRICE_CLOSE;
input int rsi_period = 14;
input bool rsi_smoothing = false;
input ENUM_RSI_RULE rsi_rule = RSI_RULE_SIGN;

input group "EMA"
input int fast_ema_period = 50;
input int slow_ema_period = 200;

input group "Martingale settings"
input double starting_lot_size = 0.01;
input double lot_factor = 1.5;
input double price_step_points = 100.0;
input double starting_tp_usd = 5;
input double tp_factor = 1.5;
input ENUM_TP_RULE tp_rule = TP_RULE_COUNT_BASED;

input group "EA settings"
input double equity_above_stop_trading = 0;  // Stop trading if account equity is above this:
input double equity_below_stop_trading = 0;  // Stop trading if account equity is below this:
input string PositionComment = "";
input int Magic = 230;  // EA's magic number

input group "News Handling"
input int suspend_minutes_before_news = 0;
input int suspend_minutes_after_news = 0;
input int no_cycle_minutes_before_news = 0;
input int no_cycle_minutes_after_news = 0;

CTrade trade;
int harsi_handle, fast_ema_handle, slow_ema_handle;
ENUM_TIMEFRAMES tf;
CNews today_news;
double lotsize;
bool force_close_positions = false;

#define HARSI_OPEN_BUFFER 0
#define HARSI_CLOSE_BUFFER 3
#define RSI_BUFFER 5

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.LogLevel(LOG_LEVEL_NO);
   tf = convert_tf(custom_timeframe);
   harsi_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\HARSI.ex5", harsi_period, harsi_smoothing, rsi_source, rsi_period, rsi_smoothing, 0, 0, 0, 0, 0, false, false);
   fast_ema_handle = iMA(_Symbol, tf, fast_ema_period, 0, MODE_EMA, PRICE_CLOSE);
   slow_ema_handle = iMA(_Symbol, tf, slow_ema_period, 0, MODE_EMA, PRICE_CLOSE);
   ChartIndicatorAdd(0, 0, fast_ema_handle);
   ChartIndicatorAdd(0, 0, slow_ema_handle);
   ChartIndicatorAdd(0, 0, harsi_handle);
   lotsize = starting_lot_size/lot_factor;
   force_close_positions = false;
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(harsi_handle);
   IndicatorRelease(fast_ema_handle);
   IndicatorRelease(slow_ema_handle);
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
   
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);   
   
   if(force_close_positions && npos>0){
      CloseAllPositions(trade, 0);
      return;
   }
   force_close_positions = false;
   
   if(no_cycle_minutes_after_news>0 || no_cycle_minutes_before_news>0 || suspend_minutes_after_news>0 || suspend_minutes_before_news>0){
      update_news();
      int nnews = ArraySize(today_news.news);
      if(nnews>0){
         for(int inews=0;inews<nnews;inews++){
            datetime newstime = today_news.news[inews].time;
            int nminutes = (int)(TimeCurrent()-newstime)/60;
            if((nminutes<=0 && -nminutes<=suspend_minutes_before_news && suspend_minutes_before_news>0) || (nminutes>=0 && nminutes<=suspend_minutes_after_news && suspend_minutes_after_news>0)) return;
            if((nminutes<=0 && -nminutes<=no_cycle_minutes_before_news && no_cycle_minutes_before_news>0) || (nminutes>=0 && nminutes<=no_cycle_minutes_after_news && no_cycle_minutes_after_news>0)){
               if(ArraySize(pos_tickets)==0) return;
            }
         }
      }
   }
   
   double desired_tp_usd, current_tp_usd, forbidden_zone_mid_price, forbidden_zone_offset_price;
   analyze_positions(desired_tp_usd, current_tp_usd, forbidden_zone_mid_price, forbidden_zone_offset_price, pos_tickets);
   if((!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)) && !MQLInfoInteger(MQL_OPTIMIZATION) && !MQLInfoInteger(MQL_FORWARD)){
      Comment(StringFormat("EA: %d     NPos: %.0d     Lotsize: %.2f     Prof: %.2f     TP: %.2f", Magic, npos, lotsize, current_tp_usd, desired_tp_usd));
   }

   if(current_tp_usd>=desired_tp_usd && npos>0){
      CloseAllPositions(trade, 0);
      lotsize = starting_lot_size/lot_factor;
      force_close_positions = true;
   }
   
   if(!IsNewCandle(tf, 5)) return;   
   if(is_friday_or_thursday() && npos==0 && dont_start_new_cycle_on_weekend) return;
   if(!is_session_time_allowed_double(session_start_hour, session_end_hour) && trade_only_in_session_time) return;
   
   int buy_or_sell = buy_or_sell_signal();
   if(buy_or_sell==1){
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(forbidden_zone_mid_price>0 && forbidden_zone_offset_price>0){
         if((entry_price<=forbidden_zone_mid_price+forbidden_zone_offset_price) && (entry_price>=forbidden_zone_mid_price-forbidden_zone_offset_price)) return;
      }
      lotsize = lotsize*lot_factor;
      double lot = normalize_volume(lotsize);
      entry_price = NormalizeDouble(entry_price, _Digits);
      trade.Buy(lot, _Symbol, entry_price, 0, 0, PositionComment);
   }else if(buy_or_sell==2){
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(forbidden_zone_mid_price>0 && forbidden_zone_offset_price>0){
         if((entry_price<=forbidden_zone_mid_price+forbidden_zone_offset_price) && (entry_price>=forbidden_zone_mid_price-forbidden_zone_offset_price)) return;
      }
      lotsize = lotsize*lot_factor;
      double lot = normalize_volume(lotsize);
      entry_price = NormalizeDouble(entry_price, _Digits);
      trade.Sell(lot, _Symbol, entry_price, 0, 0, PositionComment);
   }
}

int buy_or_sell_signal(){ // 0: nothing, 1:buy, 2:sell
   double p, fema[1], sema[1], hao[1], hac[1], rsi[2];
   p = iClose(_Symbol, tf, 1);
   CopyBuffer(fast_ema_handle, 0, 1, 1, fema);
   CopyBuffer(slow_ema_handle, 0, 1, 1, sema);
   CopyBuffer(harsi_handle, HARSI_OPEN_BUFFER, 1, 1, hao);
   CopyBuffer(harsi_handle, HARSI_CLOSE_BUFFER, 1, 1, hac);
   CopyBuffer(harsi_handle, RSI_BUFFER, 1, 2, rsi);
   if(rsi_rule==RSI_RULE_SIGN){
      if(rsi[1]>0 && p>fema[0] && p>sema[0] && fema[0]>sema[0] && hac[0]>hao[0]) return 1;
      if(rsi[1]<0 && p<fema[0] && p<sema[0] && fema[0]<sema[0] && hac[0]<hao[0]) return 2;
   }else if(rsi_rule==RSI_RULE_BREAK){
      if(rsi[1]>0 && rsi[0]<0 && p>fema[0] && fema[0]>sema[0] && hac[0]>hao[0]) return 1;
      if(rsi[1]<0 && rsi[0]>0 && p<fema[0] && fema[0]<sema[0] && hac[0]<hao[0]) return 2;
   }
   return 0;   
}

void analyze_positions(double& desired_tp_usd, double& current_tp_usd, double& forbidden_zone_mid_price, double& forbidden_zone_offset_price, ulong& pos_tickets[]){
   int npos = ArraySize(pos_tickets);
   double lotbuys = 0;
   double lotsells = 0;
   double pricebuys = 0;
   double pricesells = 0;
   current_tp_usd = 0;
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE postype = PositionGetInteger(POSITION_TYPE);
      current_tp_usd += PositionGetDouble(POSITION_PROFIT);
      if(postype == POSITION_TYPE_BUY){
         double lot = PositionGetDouble(POSITION_VOLUME);
         lotbuys += lot;
         pricebuys += lot*PositionGetDouble(POSITION_PRICE_OPEN);
      }else if(postype == POSITION_TYPE_SELL){
         double lot = PositionGetDouble(POSITION_VOLUME);
         lotsells += lot;
         pricesells += lot*PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   if(tp_rule == TP_RULE_COUNT_BASED) desired_tp_usd = starting_tp_usd*((npos-1)*tp_factor+1);
   else if(tp_rule == TP_RULE_LOT_BASED) desired_tp_usd = starting_tp_usd*((lotbuys+lotsells-starting_lot_size)*tp_factor+1);
   if(npos>0){
      //double breakeven_price = 0;
      //if(lotbuys != lotsells) breakeven_price = (pricebuys-pricesells)/(lotbuys-lotsells);
      PositionSelectByTicket(pos_tickets[npos-1]);
      forbidden_zone_mid_price = PositionGetDouble(POSITION_PRICE_OPEN);
      forbidden_zone_offset_price = price_step_points*_Point;
      //forbidden_zone_offset_price = 0;
      //if(breakeven_price>0) forbidden_zone_offset_price = MathAbs(forbidden_zone_mid_price-breakeven_price);
      //else if(breakeven_price<=0) Print("line " + __LINE__ + " WARNING!!!!!!!!!!!!!!");
   }else{
      forbidden_zone_offset_price = 0;
      forbidden_zone_offset_price = 0;
   }
   
}

bool is_friday_or_thursday(void){
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week==5 || dt.day_of_week==4;
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